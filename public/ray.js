/* tslint:disable */

let _ = null;

const canvas = document.getElementById('canvas');
// const gl = canvas.getContext('webgl');//.fillRect(0, 0, canvas.width, canvas.height);
const ctx = canvas.getContext('2d');//.fillRect(0, 0, canvas.width, canvas.height);

//   if (gl === null) {
//     alert("Unable to initialize WebGL. Your browser or machine may not support it.");
//     return;
//   }


// gl.clearColor(0.0, 0.0, 0.0, 1.0);
// // Clear the color buffer with specified clear color
// gl.clear(gl.COLOR_BUFFER_BIT);

const env2 = {
    env: {
        canvasFillStyle: (r, g, b, a) => {
            ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${a})`;

        },
        canvasFillRect: (x, y, w, h) => {
            ctx.fillRect(x, y, w, h);
//            console.log('test', x, y, w, h);
        },
        //imported_func: arg => console.log(arg),
    }

};

WebAssembly.instantiateStreaming(fetch('./build/lib.wasm'), env2)
    .then(results => {
        _ = results.instance.exports;
        _.setSeed(123);
        console.log({results});
  // Do something with the results!
    });

/**
* @param {string} arg0
* @param {number} arg1
* @param {number} arg2
* @returns {Float32Array}
*/
export function render(x, y, t, width, height) {
    if (_) {
        _.binding(x, y, t, width, height);
    }
}
