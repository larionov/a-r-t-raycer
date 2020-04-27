import * as Ray from './ray.js'
import Fps from './fps.js'

const canvas = {
    width: 640,
    height: 480
    // width: 40,
    // height: 50
};

var up = false,
    right = false,
    down = false,
    left = false,
    x = 0,
    y = 0;

const putData = (data) => {
    const ctx = document.getElementById('canvas').getContext('2d');
    ctx.putImageData(new ImageData(new Uint8ClampedArray(data), canvas.width, canvas.height), 0, 0);
};

document.getElementById('canvas').getContext('2d').fillStyle = 'black';
document.getElementById('canvas').getContext('2d').fillRect(0, 0, canvas.width, canvas.height);

let inc = 0;

const fps = new Fps(250,  document.querySelector('.fps'));
let type = 'wasm-zig';

const render = () => {

    fps.tick();

    const dt = fps.dt;

    if (up){
        y = y - 1;// * dt;
    }
    if (right){
        x = x + 1;// * dt;
    }
    if (down){
        y = y + 1;// * dt;
    }
    if (left){
        x = x - 1;// * dt;
    }


    Ray.render(x, y, fps.now , canvas.width, canvas.height);

    //setTimeout( () => {

    requestAnimationFrame(render);
    //}, 5000);
};
requestAnimationFrame(render);


document.addEventListener('keydown',press)
function press(e){
    if (e.keyCode === 38 /* up */ || e.keyCode === 87 /* w */ || e.keyCode === 90 /* z */){
        up = true
    }
    if (e.keyCode === 39 /* right */ || e.keyCode === 68 /* d */){
        right = true
    }
    if (e.keyCode === 40 /* down */ || e.keyCode === 83 /* s */){
        down = true
    }
    if (e.keyCode === 37 /* left */ || e.keyCode === 65 /* a */ || e.keyCode === 81 /* q */){
        left = true
    }
}
document.addEventListener('keyup',release)
function release(e){
    if (e.keyCode === 38 /* up */ || e.keyCode === 87 /* w */ || e.keyCode === 90 /* z */){
        up = false
    }
    if (e.keyCode === 39 /* right */ || e.keyCode === 68 /* d */){
        right = false
    }
    if (e.keyCode === 40 /* down */ || e.keyCode === 83 /* s */){
        down = false
    }
  if (e.keyCode === 37 /* left */ || e.keyCode === 65 /* a */ || e.keyCode === 81 /* q */){
    left = false
  }
}
