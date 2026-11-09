/**
 * Kingdom Come: Deliverance - Lockpicking Canvas Simulator
 */
class KcdLockpickSimulator {
  constructor(canvasId) {
    this.canvas = document.getElementById(canvasId);
    if (!this.canvas) return;
    this.ctx = this.canvas.getContext('2d');

    this.width = this.canvas.width = this.canvas.parentElement.clientWidth || 600;
    this.height = this.canvas.height = 400;

    this.center = { x: this.width * 0.5, y: this.height * 0.5 };
    this.lockRadius = 130;

    this.sweetSpotAngle = Math.random() * Math.PI * 2;
    this.sweetSpotRadius = 45 + Math.random() * 65;
    this.lockRotation = 0;

    this.cursor = { x: this.center.x, y: this.center.y };
    this.isSweetSpot = false;
    this.proximity = 0;

    this.pickHealth = 100;
    this.picksLeft = 5;
    this.isSolved = false;
    this.isTurning = false;

    this.shake = { x: 0, y: 0 };
    this.lastTime = performance.now();

    this._bindEvents();
    this._loop = this._loop.bind(this);
    requestAnimationFrame(this._loop);
  }

  _bindEvents() {
    window.addEventListener('resize', () => {
      if (this.canvas.parentElement) {
        this.width = this.canvas.width = this.canvas.parentElement.clientWidth;
        this.center = { x: this.width * 0.5, y: this.height * 0.5 };
      }
    });

    this.canvas.addEventListener('mousemove', (e) => {
      const rect = this.canvas.getBoundingClientRect();
      this.cursor.x = e.clientX - rect.left;
      this.cursor.y = e.clientY - rect.top;
    });

    window.addEventListener('keydown', (e) => {
      if (e.code === 'KeyD' || e.code === 'ArrowRight') {
        this.isTurning = true;
      }
    });

    window.addEventListener('keyup', (e) => {
      if (e.code === 'KeyD' || e.code === 'ArrowRight') {
        this.isTurning = false;
      }
    });

    // Touch / click hold support
    this.canvas.addEventListener('mousedown', (e) => {
      if (e.button === 0) this.isTurning = true;
    });
    window.addEventListener('mouseup', () => {
      this.isTurning = false;
    });
  }

  _reset() {
    this.lockRotation = 0;
    this.isSolved = false;
    this.pickHealth = 100;
    this.sweetSpotAngle = Math.random() * Math.PI * 2;
    this.sweetSpotRadius = 45 + Math.random() * 65;
  }

  _loop(time) {
    const dt = Math.min(0.05, (time - this.lastTime) / 1000);
    this.lastTime = time;

    const dx = this.cursor.x - this.center.x;
    const dy = this.cursor.y - this.center.y;

    // Sweet spot rotates with lockRotation
    const curAngle = this.sweetSpotAngle + this.lockRotation;
    const targetX = Math.cos(curAngle) * this.sweetSpotRadius;
    const targetY = Math.sin(curAngle) * this.sweetSpotRadius;

    const dist = Math.hypot(dx - targetX, dy - targetY);
    const tolerance = 22;

    this.proximity = Math.max(0, 1 - dist / (tolerance * 3.5));
    this.isSweetSpot = (dist <= tolerance);

    if (this.isTurning && !this.isSolved && this.picksLeft > 0) {
      if (this.isSweetSpot) {
        this.lockRotation += dt * 1.5;
        this.shake = { x: 0, y: 0 };
        if (window.medievalAudio) window.medievalAudio.playClick();
        if (this.lockRotation >= Math.PI * 1.2) {
          this.isSolved = true;
          if (window.medievalAudio) window.medievalAudio.playParryChime();
        }
      } else {
        // Penalty for turning outside sweet spot
        this.pickHealth -= dt * 85;
        this.shake = {
          x: (Math.random() - 0.5) * 6,
          y: (Math.random() - 0.5) * 6
        };
        if (this.pickHealth <= 0) {
          this.picksLeft = Math.max(0, this.picksLeft - 1);
          this.pickHealth = 100;
          this.lockRotation = 0;
          if (window.medievalAudio) window.medievalAudio.playSnap();
        }
      }
    } else {
      // Spring back
      if (!this.isSolved) {
        this.lockRotation = Math.max(0, this.lockRotation - dt * 2.8);
      }
      this.shake = { x: 0, y: 0 };
    }

    this._render();
    requestAnimationFrame(this._loop);
  }

  _render() {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.width, this.height);

    const cx = this.center.x + this.shake.x;
    const cy = this.center.y + this.shake.y;

    // Background
    ctx.fillStyle = '#1c1814';
    ctx.fillRect(0, 0, this.width, this.height);

    // Outer iron lockplate
    ctx.beginPath();
    ctx.arc(cx, cy, this.lockRadius + 24, 0, Math.PI * 2);
    ctx.fillStyle = '#26221c';
    ctx.fill();
    ctx.strokeStyle = '#8a6e1a';
    ctx.lineWidth = 4;
    ctx.stroke();

    // Rivets
    for (let i = 0; i < 8; i++) {
      const ang = (i * Math.PI * 2) / 8;
      const rx = cx + Math.cos(ang) * (this.lockRadius + 12);
      const ry = cy + Math.sin(ang) * (this.lockRadius + 12);
      ctx.beginPath();
      ctx.arc(rx, ry, 4, 0, Math.PI * 2);
      ctx.fillStyle = '#4a3f32';
      ctx.fill();
    }

    // Inner rotating tumbler
    ctx.beginPath();
    ctx.arc(cx, cy, this.lockRadius, 0, Math.PI * 2);
    ctx.fillStyle = '#363028';
    ctx.fill();
    ctx.strokeStyle = '#5c4f3d';
    ctx.lineWidth = 3;
    ctx.stroke();

    // Keyhole slot rotates with lockRotation
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(this.lockRotation);
    ctx.fillStyle = '#0f0e0c';
    ctx.beginPath();
    ctx.arc(0, 8, 9, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillRect(-4, -22, 8, 30);
    ctx.restore();

    // Draw Lockpick Needle tool leading to cursor
    ctx.strokeStyle = '#cbd5e0';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(cx, cy + this.lockRadius + 30);
    ctx.lineTo(this.cursor.x, this.cursor.y);
    ctx.stroke();

    // Cursor Orb: Silver if far, Glowing Gold if Sweet Spot!
    const orbRadius = 10 + this.proximity * 7;
    ctx.beginPath();
    ctx.arc(this.cursor.x, this.cursor.y, orbRadius, 0, Math.PI * 2);
    ctx.fillStyle = this.isSweetSpot ? '#f6e05e' : `rgba(214, 158, 46, ${0.3 + this.proximity * 0.6})`;
    ctx.fill();
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 2;
    ctx.stroke();

    if (this.isSweetSpot) {
      ctx.beginPath();
      ctx.arc(this.cursor.x, this.cursor.y, orbRadius + 5, 0, Math.PI * 2);
      ctx.strokeStyle = 'rgba(246, 224, 94, 0.7)';
      ctx.lineWidth = 2;
      ctx.stroke();
    }

    // Status UI
    ctx.font = '13px "Cinzel", serif';
    ctx.fillStyle = '#ffffff';
    ctx.textAlign = 'center';
    if (this.isSolved) {
      ctx.fillStyle = '#48bb78';
      ctx.font = 'bold 16px "Cinzel", serif';
      ctx.fillText("CHEST UNLOCKED! (150 Groschen & Savior Schnapps)", cx, cy + this.lockRadius + 55);
    } else if (this.picksLeft <= 0) {
      ctx.fillStyle = '#e53e3e';
      ctx.fillText("All lockpicks broken! Reset to try again.", cx, cy + this.lockRadius + 55);
    } else {
      ctx.fillText("FIND THE GOLDEN SWEET SPOT & HOLD [D] TO ROTATE", cx, cy + this.lockRadius + 55);
    }

    ctx.textAlign = 'left';
    ctx.fillText(`PICKS LEFT: ${this.picksLeft}`, 20, 30);
    ctx.textAlign = 'right';
    ctx.fillText(`TENSION: ${Math.round(100 - this.pickHealth)}%`, this.width - 20, 30);
  }
}

window.KcdLockpickSimulator = KcdLockpickSimulator;
