/**
 * Medieval Audio Synthesizer using Web Audio API
 * Generates ambient campfire, lute plucks, and metallic combat sfx.
 */
class MedievalAudio {
  constructor() {
    this.ctx = null;
    this.isMuted = true;
    this.ambientGain = null;
    this.luteInterval = null;
  }

  init() {
    if (this.ctx) return;
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    this.ctx = new AudioCtx();
    
    // Master ambient gain
    this.ambientGain = this.ctx.createGain();
    this.ambientGain.gain.setValueAtTime(0.001, this.ctx.currentTime);
    this.ambientGain.connect(this.ctx.destination);
    
    this._startCampfire();
    this._startLuteArpeggiator();
  }

  toggleSound() {
    if (!this.ctx) this.init();
    if (this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
    this.isMuted = !this.isMuted;
    if (this.ambientGain) {
      const targetGain = this.isMuted ? 0.0001 : 0.22;
      this.ambientGain.gain.exponentialRampToValueAtTime(targetGain, this.ctx.currentTime + 0.8);
    }
    return !this.isMuted;
  }

  _startCampfire() {
    // Pink noise buffer with lowpass filter for gentle crackling tavern/campfire
    const bufferSize = this.ctx.sampleRate * 2;
    const noiseBuffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const output = noiseBuffer.getChannelData(0);
    let b0 = 0, b1 = 0, b2 = 0;
    for (let i = 0; i < bufferSize; i++) {
      const white = Math.random() * 2 - 1;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      output[i] = (b0 + b1 + b2) * 0.12;
    }

    const whiteNoise = this.ctx.createBufferSource();
    whiteNoise.buffer = noiseBuffer;
    whiteNoise.loop = true;

    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(450, this.ctx.currentTime);

    whiteNoise.connect(filter);
    filter.connect(this.ambientGain);
    whiteNoise.start();
  }

  _startLuteArpeggiator() {
    // Medieval D-Dorian / Bohemian folk chord progression: Dm - C - Bb - Am
    const progressions = [
      [293.66, 349.23, 440.00, 587.33], // Dm
      [261.63, 329.63, 392.00, 523.25], // C
      [233.08, 293.66, 349.23, 466.16], // Bb
      [220.00, 261.63, 329.63, 440.00], // Am
    ];

    let chordIdx = 0;
    let noteIdx = 0;

    setInterval(() => {
      if (this.isMuted || !this.ctx) return;
      const currentChord = progressions[chordIdx];
      const freq = currentChord[noteIdx % currentChord.length];
      this.playPluckedString(freq, 0.45);

      noteIdx++;
      if (noteIdx >= 4) {
        noteIdx = 0;
        chordIdx = (chordIdx + 1) % progressions.length;
      }
    }, 450);
  }

  playPluckedString(freq, volume = 0.3) {
    if (!this.ctx || this.isMuted) return;
    const now = this.ctx.currentTime;
    
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc.type = 'triangle';
    osc.frequency.setValueAtTime(freq, now);

    // Natural decay curve of a lute gut string
    gain.gain.setValueAtTime(volume * 0.35, now);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 1.2);

    osc.connect(gain);
    gain.connect(this.ctx.destination);

    osc.start(now);
    osc.stop(now + 1.2);
  }

  playClash() {
    if (!this.ctx || this.isMuted) return;
    const now = this.ctx.currentTime;
    
    // Two high metallic frequencies with sharp decay
    [840, 1420].forEach((freq) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, now);
      osc.frequency.exponentialRampToValueAtTime(freq * 0.8, now + 0.3);

      gain.gain.setValueAtTime(0.4, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);

      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start(now);
      osc.stop(now + 0.35);
    });
  }

  playParryChime() {
    if (!this.ctx || this.isMuted) return;
    const now = this.ctx.currentTime;
    
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(1280, now);
    osc.frequency.exponentialRampToValueAtTime(1920, now + 0.08);

    gain.gain.setValueAtTime(0.5, now);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.6);

    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.6);
  }

  playClick() {
    if (!this.ctx || this.isMuted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'square';
    osc.frequency.setValueAtTime(1600, now);
    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.04);
  }

  playSnap() {
    if (!this.ctx || this.isMuted) return;
    const now = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(450, now);
    osc.frequency.exponentialRampToValueAtTime(180, now + 0.15);
    gain.gain.setValueAtTime(0.6, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.15);
  }
}

window.medievalAudio = new MedievalAudio();
