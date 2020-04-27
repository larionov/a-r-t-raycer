export default class Fps {
    constructor(interval, element) {
        this.lastTick = performance.now();
        this.lastNotify = this.lastTick;
        this.interval = interval;
        this.element = element;
        this.runningSum = 0;
        this.runningSamples = 0;
        this.dt = 1;
        this.now = 0;
    }

    tick() {
        this.now = performance.now();
        this.runningSum += (this.now - this.lastTick);
        this.runningSamples++;
        this.lastTick = this.now;

        this.dt = 3.0 / (this.now - this.lastNotify);

        if ((this.now - this.lastNotify) > this.interval) {
            this.notify(this.now);
        }
    }

    notify(now) {
        const avgFrame = this.runningSum / this.runningSamples;
        const fps = 1000 / avgFrame;
        this.element.innerText = `${fps.toFixed(2)}fps`;
        this.lastNotify = now;
        this.runningSamples = 0;
        this.runningSum = 0;
    }
}
