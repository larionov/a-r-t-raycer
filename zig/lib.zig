// zig@0.6.0
// Build:
// $ zig build-lib --release-fast --output-dir ./pkg/ -target wasm32-freestanding-none lib.zig

const AtomicOrder = @import("builtin").AtomicOrder;
const Vector = @import("vector.zig").Vector(f32);

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const warn = std.debug.warn;
const allocator = std.heap.page_allocator;

const Math= std.math;
const json = std.json;
const ArrayList = std.ArrayList;

const SELF_INTERSECTION_THRESHOLD: f32 = 0.001;

const Ray = struct {
    point: Vector,
    vector: Vector,
};

const ObjectType = enum {
    Plane,
    Sphere,
};


const Scene = struct {
    const Camera = struct {
        point: Vector,
        vector: Vector,
        fov: f32,
    };
    camera: Camera,

    const Object = struct {
        @"type": ObjectType,
        point: Vector,
        color: Vector,
        specular: f32,
        lambert: f32,
        ambient: f32,
        radius: f32 = 0.0,
        normal: Vector = Vector.new(0.0, 0.0, 0.0),
    };

    objects: []const Object,
    lights: []const Vector,
    checker: []const Vector,
};

fn closer(a: ?f32, b: ?f32) bool {
    if (a !=null and b != null)
        return (a.? > SELF_INTERSECTION_THRESHOLD and a.? < b.?);

    if (a == null and b == null)
        return false;

    return a orelse 0.0 > SELF_INTERSECTION_THRESHOLD;
}

const IntersectionResult = struct {
    distance: ?f32,
    object: ?Scene.Object,
};

fn intersect_scene(ray: Ray, scene: Scene) IntersectionResult {
    var closest = IntersectionResult{ .distance = null, .object = null };

    for (scene.objects) |object| {
        var distance = object_intersection(object, ray);
        if (closer(distance, closest.distance)) {
            closest = IntersectionResult{
                .distance = distance,
                .object = object
            };
        }
    }

    return closest;
}

fn object_intersection(object: Scene.Object, ray: Ray) ?f32 {
    return switch (object.type) {
        ObjectType.Sphere => blk: {
            const eye_to_center = object.point.subtract(ray.point);
            const v = eye_to_center.dot_product(ray.vector);
            const eo_dot = eye_to_center.dot_product(eye_to_center);
            const discriminant = (object.radius * object.radius) - eo_dot + (v * v);

            if (discriminant < 0.0) {
                return null;
            }

            const distance = v - Math.sqrt(discriminant);

            if (distance > SELF_INTERSECTION_THRESHOLD) {
                return distance;
            }

            break :blk null;
        },
        ObjectType.Plane =>  blk: {
            const neg_norm = object.normal.negate();
            const denom = neg_norm.dot_product(ray.vector);

            if (denom <= 0.0) {
                return null;
            }

            const interm = object.point.subtract(ray.point);
            break :blk interm.dot_product(neg_norm) / denom;
        },
        else => null

    };
}


fn plane_color_at(point_at_time: Vector, plane: Scene.Object, scene: Scene) Vector {
   // Point from plane origin
    // This is a complete hack to make up for my sad lack of lin alg. knowledge

    const from_origin = point_at_time.subtract(plane.point);
    const width = 2.0;

    var px = Vector.new(0.0, 1.0, 0.0);
    var py = Vector.new(0.0, 0.0, 1.0);

    if (plane.normal.z != 0.0) {
        py = Vector.new(1.0, 0.0, 1.0);
    }

    if (plane.normal.y != 0.0) {
        px = Vector.new(0.0, 0.0, 1.0);
        py = Vector.new(1.0, 0.0, 0.0);
    }

    const cx = px.dot_product(from_origin);
    const cy = py.dot_product(from_origin);

    const x_cond = (cx < 0.0 and @rem(cx, width) < -width / 2.0) or (cx > 0.0 and @rem(cx, width) < width / 2.0);
    const y_cond = (cy < 0.0 and @rem(cy, width) < -width / 2.0) or (cy > 0.0 and @rem(cy, width) < width / 2.0);

    if ((x_cond and !y_cond) or (y_cond and !x_cond)) {
        return scene.checker[0].scale(1.0);
    }

    return scene.checker[1].scale(1.0);
}

fn get_normal(object: Scene.Object, pos: Vector) Vector {
    return switch (object.type) {
        ObjectType.Sphere => pos.subtract(object.point).unit(),
        ObjectType.Plane => object.normal.unit(),
        else => Vector.new(0.0, 0.0, 0.0),
    };
}

fn surface(
    ray: Ray,
    scene: Scene,
    object: Scene.Object,
    point_at_time: Vector,
    normal: Vector,
    depth: usize,
) Vector {
    var lambert = object.lambert;
    var specular = object.specular;
    var ambient = object.ambient;
    var b = switch (object.type) {
        ObjectType.Sphere => object.color.scale(1.0),
        ObjectType.Plane => plane_color_at(point_at_time, object, scene),
    };

    var c = Vector.zero();
    var lambert_amount: f32 = 0.0;

    if (lambert > 0.0) {
        for (scene.lights) |light| {
            if (!is_light_visible(point_at_time, scene, light)) {
                continue;
            }

            const contribution = light.subtract(point_at_time).unit().dot_product(normal);

            if (contribution > 0.0) {
                lambert_amount += contribution;
            }
        }
    }

    if (specular > 0.0) {
        const reflected_ray = Ray{
            .point = point_at_time,
            .vector = ray.vector.reflect_through(normal),
        };
        const reflected_color = trace(reflected_ray, scene, depth + 1);
        if (reflected_color != null) {
            c = c.add(reflected_color.?.scale(specular));
        }
    }

    lambert_amount = min(lambert_amount, 1.0);
    return c.add3(b.scale(lambert_amount * lambert), b.scale(ambient));
}

fn is_light_visible(point: Vector, scene: Scene, light: Vector) bool {
    const point_to_light_vector = light.subtract(point);
    const distance_to_light = point_to_light_vector.length();

    const ray = Ray {
        .point = point,
        .vector = point_to_light_vector.unit(),
    };
    const res = intersect_scene(ray, scene);
    return if (res.distance != null) res.distance.? > distance_to_light else true;
}

fn min(a: f32, b: f32) f32 {
    return if (a > b) b else a;
}

fn trace(ray: Ray, scene: Scene, depth: usize)  ?Vector {
    if (depth > 20) {
        return null;
    }

    var dist_object = intersect_scene(ray, scene);

    return if (dist_object.distance) |distance| (
        if (dist_object.object) |collision| blk: {
            const point_in_time = ray.point.add(ray.vector.scale(distance));
            break :blk surface(
                ray,
                scene,
                collision,
                point_in_time,
                get_normal(collision, point_in_time),
                depth
            );
        } else Vector.zero()
    ) else Vector.zero();
}

const Sample = struct {
    color: Vector,
    x: u32,
    y: u32,
};

fn f(v: var) f32 {
    return @intToFloat(f32, v);
}

fn u(v: var) u32 {
    return @floatToInt(u32, v);

}

fn log(comptime fmt: []const u8, args: var) void {
    if (std.Target.current.os.tag == .linux) {
        std.debug.warn("\n", .{});
        std.debug.warn(fmt, args);
    }
}

fn render_rect(scene: Scene, canvas_width: u32, canvas_height: u32, x: u32,  y: u32, width: u32, height: u32, index: u32) !void {
    const quality: f32 = 100.0;
    const clamp = Math.clamp;

//    var r = std.rand.DefaultPrng.init(seed);

    const w = @intToFloat(f32, width);
    const h = @intToFloat(f32, height);

    const camera = scene.camera;
    const eye_vector = camera.vector.subtract(camera.point).unit();
    const vp_right = eye_vector.cross_product(Vector.up()).unit();
    const vp_up = vp_right.cross_product(eye_vector).unit();

    const fov_radians = Math.pi * (camera.fov / 2.0) / 180.0;
    const height_width_ratio = f(canvas_height) / f(canvas_width); //f(height) / f(width);
    const half_width = Math.tan(fov_radians);
    const half_height = height_width_ratio * half_width;
    const camera_width = half_width * 2.0;
    const camera_height = half_height * 2.0;
    const pixel_width = camera_width / f(canvas_width);//(f(width) - 1.0);
    const pixel_height = camera_height / f(canvas_height);//(f(height) - 1.0);

    var ray = Ray{
        .point = camera.point,
        .vector = Vector.up(),
    };

    var num = u(Math.round(w * h / 10000.0 * quality));

    const new_samples = 1;
    const sample_area = w * h / f(new_samples);
    const columns = @round(w / Math.sqrt(sample_area));
    const rows = @ceil(f(new_samples) / columns);
    const cell_width = w / columns;
    const cell_height = h / rows;

//    if ((width * height <= 100)) {
    if (index > 10) {
        var i: u32 = 0;

        const the_x = f(x + rand.?.random.uintLessThan(u32, u(cell_width)));
        const the_y = f(y + rand.?.random.uintLessThan(u32, u(cell_height)));

        // const the_x = f(x) + 0.5 * cell_width;
        // const the_y = f(y) + 0.5 * cell_height;

        const x_comp = vp_right.scale((the_x * pixel_width) - half_width);
        const y_comp = vp_up.scale((the_y * pixel_height) - half_height);
        ray.vector = eye_vector.add3(x_comp, y_comp).unit();

        const color = trace(ray, scene, 0) orelse Vector.new(0.0, 0.0, 0.0);
        fill_rect(x, y, width, height, color, 5);
    } else {
        if (width > height) {
            var w_split: u32 = u(@floor(w * 0.5));
            render_rect(scene, canvas_width, canvas_height, x,           y, w_split, height, index + 1) catch unreachable;
            render_rect(scene, canvas_width, canvas_height, x  + w_split, y, width - w_split, height, index + 1)  catch unreachable;
        } else {
            var h_split: u32 = u(@floor(h * 0.5));
            render_rect(scene, canvas_width, canvas_height, x, y,           width, h_split, index + 1) catch unreachable;
            render_rect(scene, canvas_width, canvas_height, x, y + h_split, width, height - h_split, index + 1)  catch unreachable;
        }
    }

}

fn fill_rect(x: u32, y: u32, w: u32, h: u32, color: Vector, resolution: u32) void {
    log("fill_rect({d}, {d}, {d}, {d})", .{x, y, w, h});
    const clamp = Math.clamp;
    global_count += 1;

    if (std.Target.current.os.tag != .linux) {
        canvasFillStyle(u(color.x), u(color.y), u(color.z), 10);
    } else {
        log("canvasFillStyle({d}, {d}, {d}, {d});", .{u(color.x), u(color.y), u(color.z), 10});
    }
    if (rand == null) {
        return;
    }
    const center_x = x + rand.?.random.uintLessThan(u32, w);
    const center_y = y + rand.?.random.uintLessThan(u32, h);

    const radius = Math.min(center_y, Math.min(center_x, resolution));
    log("radius {d}", .{radius});
    if (std.Target.current.os.tag != .linux) {
        canvasFillRect(center_x - radius, center_y - radius, radius, radius);
    } else {
        log("canvasFillRect({d}, {d}, {d}, {d});", .{center_x - radius, center_y - radius, radius, radius});
    }
}

var global_count: u32 = 0;
fn render(x: i32, y: i32, t: u32, width: u32, height: u32) !void {
    global_count = 0;
    var ft = f(t) / 1000;
    var scene = Scene{
        .camera = Scene.Camera{
            .point = Vector{ .x = f(x), .y = f(y), .z = 7 },
            .vector = Vector{ .x = 0, .y = 0, .z = 0 },
            .fov = 70
        },
        .objects = &[_]Scene.Object{
            Scene.Object{
                .type = ObjectType.Sphere,
                .point = Vector{ .x = Math.sin(ft) * 3.0, .y = Math.sin(ft) * 2.0, .z = Math.cos(ft) * 3.0 },
                .color = Vector{ .x = 0, .y = 0, .z = 0 },
                .specular = 0.699999988079071,
                .lambert = 0.5,
                .ambient = 0.30000001192092896,
                .radius = 1,
                .normal = Vector{ .x = 0, .y = 0, .z = 0 }
            },
            Scene.Object{
                .type = ObjectType.Sphere,
                .point = Vector{ .x = Math.sin(ft) * -3.0, .y = Math.cos(ft) * -3.0, .z = Math.cos(ft) * -2.0 },
                .color = Vector{ .x = 0, .y = 0, .z = 0 },
                .specular = 0.699999988079071,
                .lambert = 0.5,
                .ambient = 0.30000001192092896,
                .radius = 1,
                .normal = Vector{ .x = 0, .y = 0, .z = 0 }
            },
            Scene.Object{ .type = ObjectType.Sphere, .point = Vector{ .x = 0, .y = 0, .z = 0 }, .color = Vector{ .x = 255, .y = 255, .z = 255 }, .specular = 0.25, .lambert = 0.7200000286102295, .ambient = 0.25999999046325684, .radius = 1.5, .normal = Vector{ .x = 0, .y = 0, .z = 0 } },
            Scene.Object{ .type = ObjectType.Plane, .point = Vector{ .x = 0, .y = 5, .z = 0 }, .color = Vector{ .x = 200, .y = 200, .z = 200 }, .specular = 0, .lambert = 0.8999999761581421, .ambient = 0.20000000298023224, .radius = 0, .normal = Vector{ .x = 0, .y = -1, .z = 0 } },
            Scene.Object{ .type = ObjectType.Plane, .point = Vector{ .x = 0, .y = -5, .z = 0 }, .color = Vector{ .x = 100, .y = 100, .z = 100 }, .specular = 0, .lambert = 0.8999999761581421, .ambient = 0.20000000298023224, .radius = 0, .normal = Vector{ .x = 0, .y = 1, .z = 0 } },
            Scene.Object{ .type = ObjectType.Plane, .point = Vector{ .x = -5, .y = 0, .z = 0 }, .color = Vector{ .x = 100, .y = 100, .z = 100 }, .specular = 0, .lambert = 0.8999999761581421, .ambient = 0.20000000298023224, .radius = 0, .normal = Vector{ .x = 1, .y = 0, .z = 0 } },
            Scene.Object{ .type = ObjectType.Plane, .point = Vector{ .x = 5, .y = 0, .z = 0 }, .color = Vector{ .x = 100, .y = 100, .z = 100 }, .specular = 0, .lambert = 0.8999999761581421, .ambient = 0.20000000298023224, .radius = 0, .normal = Vector{ .x = -1, .y = 0, .z = 0 } },
            Scene.Object{ .type = ObjectType.Plane, .point = Vector{ .x = 0, .y = 0, .z = -12 }, .color = Vector{ .x = 100, .y = 100, .z = 100 }, .specular = 0, .lambert = 0.8999999761581421, .ambient = 0.20000000298023224, .radius = 0, .normal = Vector{ .x = 0, .y = 0, .z = 1 } },
            Scene.Object{ .type = ObjectType.Plane, .point = Vector{ .x = 0, .y = 0, .z = 12 }, .color = Vector{ .x = 100, .y = 100, .z = 100 }, .specular = 0, .lambert = 0.8999999761581421, .ambient = 0.20000000298023224, .radius = 0, .normal = Vector{ .x = 0, .y = 0, .z = -1 } }
        },
        .lights = &[_]Vector{
            Vector{ .x = 3, .y = 3, .z = 5 }
        },
        .checker = &[_]Vector{
            Vector{ .x = 50, .y = 0, .z = 89 },
            Vector{ .x = 92, .y = 209, .z = 92 }
        }
    };

    //fill_rect(canvasMemoryPointer.?.ptr, width, 0, 0, 10, 10, Vector{.x = 100, .y = 200, .z = 50});
    try render_rect(scene, width, height, 0, 0, width, height, 0);
    log("total count {d} ", .{ global_count });
}

extern fn canvasFillRect(x: u32, y: u32, w: u32, h: u32) void;
extern fn canvasFillStyle(r: u32, g: u32, b: u32, a: u32) void;

var rand : ?std.rand.Xoroshiro128 = null;
export fn setSeed(seed: u32) void {
    rand = std.rand.Xoroshiro128.init(seed);
}

export fn binding(x: i32, y: i32, t: u32, width: u32, height: u32) void {
    @fence(AtomicOrder.SeqCst);

    render(x, y, t, width, height) catch unreachable;

//    canvasFillStyle(10, 100, 200, 255);
//    canvasFillRect(10, 10, 100, 100);
}

const testing = std.testing;
test "json.parse" {
    log("--------------------", .{});
    setSeed(1412150);
    var result = render(0, 0, 0, 640, 480) catch unreachable;


    log("count {d}", .{ global_count });
    // just testing if it fails
//    testing.expect(result.len == 3145728);
    //testing.expectEqual(result.len, 8000);
}
