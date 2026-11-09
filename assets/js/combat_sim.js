/**
 * Kingdom Come: Deliverance - Directional Combat Canvas Simulator
 * Authentic 5-Point Rose directional swordplay in the browser.
 */
class KcdCombatSimulator {
  constructor(canvasId) {
    this.canvas = document.getElementById(canvasId);
    if (!this.canvas) return;
    this.ctx = this.canvas.getContext('2d');
    
    this.width = this.canvas.width = this.canvas.parentElement.clientWidth || 800;
    this.height = this.canvas.height = 480;

    // Direction enums
    // 0: Top, 1: Top-Right, 2: Bottom-Right, 3: Bottom-Left, 4: Top-Left, 5: Thrust
    this.currentDirection = 0;
    this.mousePos = { x: this.width * 0.5, y: this.height * 0.5 };

    // Player (Henry)
    this.player = {
      x: this.width * 0.32,
      y: this.height * 0.65,
      hp: 100,
      maxHp: 100,
      stamina: 100,
      maxStamina: 100,
      isBlocking: false,
      isAttacking: false,
      attackProgress: 0,
      attackDir: 0,
      isThrust: false,
      perfectParryWindow: 0,
      score: 0
    };

    // Enemy (Cuman Raider)
    this.cuman = {
      x: this.width * 0.68,
      y: this.height * 0.65,
      hp: 100,
      maxHp: 100,
      stamina: 80,
      maxStamina: 80,
      guardDir: 1,
      isWindingUp: false,
      windupTimer: 0,
      isAttacking: false,
      attackProgress: 0,
      aiCooldown: 1.5,
      statusText: "Ready",
      statusTimer: 0
    };

    this.particles = [];
    this.floatingTexts = [];
    this.lastTime = performance.now();

    this._bindEvents();
    this._loop = this._loop.bind(this);
    requestAnimationFrame(this._loop);
  }

  _bindEvents() {
    window.addEventListener('resize', () => {
      if (this.canvas.parentElement) {
        this.width = this.canvas.width = this.canvas.parentElement.clientWidth;
        this.player.x = this.width * 0.32;
        this.cuman.x = this.width * 0.68;
      }
    });

    this.canvas.addEventListener('mousemove', (e) => {
      const rect = this.canvas.getBoundingClientRect();
      this.mousePos.x = e.clientX - rect.left;
      this.mousePos.y = e.clientY - rect.top;

      // Calculate directional sector relative to center of the 5-point star
      const starCenter = { x: this.width * 0.5, y: this.height * 0.36 };
      const dx = this.mousePos.x - starCenter.x;
      const dy = this.mousePos.y - starCenter.y;
      const dist = Math.hypot(dx, dy);

      if (dist < 26) {
        this.currentDirection = 5; // Thrust center
      } else {
        const deg = Math.atan2(dy, dx) * (180 / Math.PI);
        if (deg < -126 || deg > 126) this.currentDirection = (deg > 0) ? 3 : 4; // BL or TL
        else if (deg >= -126 && deg < -54) this.currentDirection = 0; // Top
        else if (deg >= -54 && deg < 18) this.currentDirection = 1; // TR
        else if (deg >= 18 && deg <= 90) this.currentDirection = 2; // BR
        else this.currentDirection = 3; // BL
      }
    });

    this.canvas.addEventListener('mousedown', (e) => {
      e.preventDefault();
      if (window.medievalAudio) window.medievalAudio.init();
      if (e.button === 0) {
        // Left Click -> Slash
        this._playerSlash();
      } else if (e.button === 1) {
        // Middle Click -> Thrust
        this._playerThrust();
      } else if (e.button === 2) {
        // Right Click -> Block
        this._startBlock();
      }
    });

    this.canvas.addEventListener('mouseup', (e) => {
      if (e.button === 2) {
        this.player.isBlocking = false;
      }
    });

    this.canvas.addEventListener('contextmenu', (e) => e.preventDefault());

    window.addEventListener('keydown', (e) => {
      if (e.code === 'Space') {
        e.preventDefault();
        this._startBlock();
      } else if (e.code === 'KeyF') {
        this._playerThrust();
      }
    });

    window.addEventListener('keyup', (e) => {
      if (e.code === 'Space') {
        this.player.isBlocking = false;
      }
    });
  }

  _startBlock() {
    this.player.isBlocking = true;
    this.player.perfectParryWindow = 0.35; // Perfect block timing window
    if (window.medievalAudio) window.medievalAudio.playClash();
  }

  _playerSlash() {
    if (this.player.isAttacking || this.player.stamina < 15 || this.player.hp <= 0) return;
    this.player.isAttacking = true;
    this.player.attackProgress = 0;
    this.player.attackDir = this.currentDirection;
    this.player.isThrust = (this.currentDirection === 5);
    this.player.stamina -= 16;
    if (window.medievalAudio) window.medievalAudio.playPluckedString(340, 0.4);

    // Evaluate hit against Cuman
    setTimeout(() => {
      this._evaluatePlayerHit();
    }, 180);
  }

  _playerThrust() {
    if (this.player.isAttacking || this.player.stamina < 12 || this.player.hp <= 0) return;
    this.player.isAttacking = true;
    this.player.attackProgress = 0;
    this.player.attackDir = 5;
    this.player.isThrust = true;
    this.player.stamina -= 14;
    if (window.medievalAudio) window.medievalAudio.playPluckedString(480, 0.5);

    setTimeout(() => {
      this._evaluatePlayerHit();
    }, 150);
  }

  _evaluatePlayerHit() {
    if (this.cuman.hp <= 0) return;

    // Check if Cuman matches guard direction
    const isBlocked = (this.cuman.guardDir === this.player.attackDir && this.cuman.stamina > 15 && !this.cuman.isWindingUp);

    if (isBlocked) {
      this.cuman.stamina -= 20;
      if (window.medievalAudio) window.medievalAudio.playClash();
      this._addFloatingText(this.cuman.x, this.cuman.y - 70, "BLOCKED!", "#d0d4dc");
      this._spawnSparks(this.width * 0.5, this.height * 0.62, 12);
    } else {
      const dmg = (this.player.isThrust ? 22 : 28);
      this.cuman.hp = Math.max(0, this.cuman.hp - dmg);
      this.cuman.stamina -= 12;
      this.player.score += 50;
      if (window.medievalAudio) window.medievalAudio.playClash();
      this._addFloatingText(this.cuman.x, this.cuman.y - 70, `-${dmg}`, "#e53e3e");
      this._spawnBlood(this.cuman.x, this.cuman.y - 20, 15);

      if (this.cuman.hp <= 0) {
        this._onCumanDefeated();
      }
    }
  }

  _onCumanDefeated() {
    if (window.medievalAudio) window.medievalAudio.playParryChime();
    this._addFloatingText(this.cuman.x, this.cuman.y - 90, "CUMAN ROUTED! (+200 Groschen)", "#ecc94b");
    setTimeout(() => {
      this.cuman.hp = this.cuman.maxHp;
      this.cuman.stamina = this.cuman.maxStamina;
      this.cuman.guardDir = Math.floor(Math.random() * 5);
      this._addFloatingText(this.cuman.x, this.cuman.y - 90, "New Cuman Raider stepped forth!", "#ffffff");
    }, 2200);
  }

  _updateAI(dt) {
    if (this.cuman.hp <= 0) return;

    this.cuman.stamina = Math.min(this.cuman.maxStamina, this.cuman.stamina + dt * 16);
    this.cuman.aiCooldown -= dt;

    if (this.cuman.isWindingUp) {
      this.cuman.windupTimer -= dt;
      if (this.cuman.windupTimer <= 0) {
        this._executeCumanAttack();
      }
    } else if (this.cuman.aiCooldown <= 0) {
      this.cuman.aiCooldown = 1.4 + Math.random() * 1.6;
      // Change stance or start attack
      if (Math.random() < 0.65 && this.cuman.stamina >= 20) {
        this._startCumanAttack();
      } else {
        this.cuman.guardDir = Math.floor(Math.random() * 5);
      }
    }
  }

  _startCumanAttack() {
    this.cuman.isWindingUp = true;
    this.cuman.windupTimer = 0.48; // Windup before strike
    this.cuman.guardDir = Math.floor(Math.random() * 5);
    // Green shield flash for player!
    this.cuman.statusText = "STRIKE INCOMING!";
    this.cuman.statusTimer = 0.5;
  }

  _executeCumanAttack() {
    this.cuman.isWindingUp = false;
    this.cuman.stamina -= 18;

    if (this.player.isBlocking) {
      if (this.player.perfectParryWindow > 0) {
        // MASTER STRIKE / RIPOSTE!
        if (window.medievalAudio) window.medievalAudio.playParryChime();
        this._addFloatingText(this.player.x + 30, this.player.y - 80, "MASTER STRIKE! (Riposte)", "#ecc94b");
        this._spawnSparks(this.width * 0.5, this.height * 0.62, 20);
        this.cuman.hp = Math.max(0, this.cuman.hp - 32);
        this.player.stamina = Math.min(this.player.maxStamina, this.player.stamina + 20);
        this.player.score += 100;
        if (this.cuman.hp <= 0) this._onCumanDefeated();
        return;
      } else {
        // Normal block
        this.player.stamina = Math.max(0, this.player.stamina - 22);
        if (window.medievalAudio) window.medievalAudio.playClash();
        this._addFloatingText(this.player.x, this.player.y - 70, "BLOCKED!", "#90cdf4");
        this._spawnSparks(this.width * 0.5, this.height * 0.62, 10);
        return;
      }
    }

    // Direct hit on Henry!
    const dmg = 24;
    this.player.hp = Math.max(0, this.player.hp - dmg);
    if (window.medievalAudio) window.medievalAudio.playClash();
    this._addFloatingText(this.player.x, this.player.y - 70, `-${dmg}`, "#e53e3e");
    this._spawnBlood(this.player.x, this.player.y - 20, 15);

    if (this.player.hp <= 0) {
      this._addFloatingText(this.player.x, this.player.y - 90, "Henry has fallen! Click to revive.", "#e53e3e");
      setTimeout(() => {
        this.player.hp = this.player.maxHp;
        this.player.stamina = this.player.maxStamina;
      }, 3000);
    }
  }

  _spawnSparks(x, y, count) {
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = 80 + Math.random() * 180;
      this.particles.push({
        x, y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 0.3 + Math.random() * 0.2,
        color: '#f6ad55',
        size: 2 + Math.random() * 2
      });
    }
  }

  _spawnBlood(x, y, count) {
    for (let i = 0; i < count; i++) {
      const angle = -Math.PI * 0.5 + (Math.random() - 0.5) * 1.5;
      const speed = 50 + Math.random() * 120;
      this.particles.push({
        x, y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 0.4 + Math.random() * 0.3,
        color: '#9b2c2c',
        size: 3 + Math.random() * 2
      });
    }
  }

  _addFloatingText(x, y, text, color) {
    this.floatingTexts.push({ x, y, text, color, life: 1.0, dy: -35 });
  }

  _loop(time) {
    const dt = Math.min(0.05, (time - this.lastTime) / 1000);
    this.lastTime = time;

    // Regens
    if (!this.player.isBlocking) {
      this.player.stamina = Math.min(this.player.maxStamina, this.player.stamina + dt * 22);
    }
    if (this.player.perfectParryWindow > 0) {
      this.player.perfectParryWindow -= dt;
    }

    if (this.player.isAttacking) {
      this.player.attackProgress += dt * 3.5;
      if (this.player.attackProgress >= 1.0) {
        this.player.isAttacking = false;
        this.player.attackProgress = 0;
      }
    }

    this._updateAI(dt);

    // Update particles
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 300 * dt; // gravity
      if (p.life <= 0) this.particles.splice(i, 1);
    }

    // Update text
    for (let i = this.floatingTexts.length - 1; i >= 0; i--) {
      const t = this.floatingTexts[i];
      t.life -= dt;
      t.y += t.dy * dt;
      if (t.life <= 0) this.floatingTexts.splice(i, 1);
    }

    this._render();
    requestAnimationFrame(this._loop);
  }

  _render() {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.width, this.height);

    // Background: Medieval Bohemian courtyard backdrop
    const grad = ctx.createLinearGradient(0, 0, 0, this.height);
    grad.addColorStop(0, '#1a1612');
    grad.addColorStop(0.5, '#26201a');
    grad.addColorStop(1, '#15120e');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, this.width, this.height);

    // Cobblestone ground
    ctx.fillStyle = '#2d261e';
    ctx.fillRect(0, this.height * 0.72, this.width, this.height * 0.28);
    ctx.strokeStyle = 'rgba(212, 175, 55, 0.15)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, this.height * 0.72);
    ctx.lineTo(this.width, this.height * 0.72);
    ctx.stroke();

    // Draw the 5-point Directional Combat Reticle at center
    this._drawCombatRose();

    // Draw Henry & Cuman
    this._drawFighter(this.player, true);
    this._drawFighter(this.cuman, false);

    // Draw Particles & Floating Texts
    this.particles.forEach((p) => {
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fill();
    });

    this.floatingTexts.forEach((t) => {
      ctx.font = 'bold 15px "MedievalSharp", "Cinzel", serif';
      ctx.fillStyle = t.color;
      ctx.textAlign = 'center';
      ctx.fillText(t.text, t.x, t.y);
    });

    // Score & Controls HUD
    ctx.font = '12px "Cinzel", serif';
    ctx.fillStyle = '#d4af37';
    ctx.textAlign = 'left';
    ctx.fillText(`SCORE: ${this.player.score}`, 20, 30);
    ctx.textAlign = 'center';
    ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
    ctx.fillText("MOUSE: AIM ROSE  •  LMB: SLASH  •  RMB / SPACE: PARRY / MASTER STRIKE  •  F: THRUST", this.width * 0.5, this.height - 15);
  }

  _drawCombatRose() {
    const ctx = this.ctx;
    const center = { x: this.width * 0.5, y: this.height * 0.36 };
    const radius = 54;

    const angles = [
      -Math.PI * 0.5, // 0: Top
      -Math.PI * 0.1, // 1: Top-Right
      Math.PI * 0.3,  // 2: Bottom-Right
      Math.PI * 0.7,  // 3: Bottom-Left
      -Math.PI * 0.9  // 4: Top-Left
    ];

    // Petal lines
    angles.forEach((ang, idx) => {
      const isPlayerActive = (this.currentDirection === idx);
      const isCumanGuard = (this.cuman.guardDir === idx);

      const dx = Math.cos(ang);
      const dy = Math.sin(ang);
      const p1 = { x: center.x + dx * 14, y: center.y + dy * 14 };
      const p2 = { x: center.x + dx * radius, y: center.y + dy * radius };

      ctx.beginPath();
      ctx.moveTo(p1.x, p1.y);
      ctx.lineTo(p2.x, p2.y);
      ctx.lineWidth = isPlayerActive ? 4 : 2;
      ctx.strokeStyle = isPlayerActive ? '#e53e3e' : 'rgba(212, 175, 55, 0.35)';
      ctx.stroke();

      // Arrowhead
      ctx.fillStyle = isPlayerActive ? '#f6ad55' : (isCumanGuard ? '#3182ce' : 'rgba(212, 175, 55, 0.5)');
      ctx.beginPath();
      ctx.arc(p2.x, p2.y, isPlayerActive ? 6 : 4, 0, Math.PI * 2);
      ctx.fill();
    });

    // Center hub (Thrust)
    const isThrustActive = (this.currentDirection === 5);
    ctx.beginPath();
    ctx.arc(center.x, center.y, 9, 0, Math.PI * 2);
    ctx.fillStyle = isThrustActive ? '#e53e3e' : '#4a3828';
    ctx.fill();
    ctx.strokeStyle = '#d4af37';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Perfect Block (Green Shield Prompt)
    if (this.cuman.isWindingUp) {
      const shieldScale = 1.0 + Math.sin(performance.now() * 0.02) * 0.15;
      ctx.fillStyle = '#48bb78';
      ctx.beginPath();
      ctx.moveTo(center.x - 12 * shieldScale, center.y - 12 * shieldScale);
      ctx.lineTo(center.x + 12 * shieldScale, center.y - 12 * shieldScale);
      ctx.lineTo(center.x + 10 * shieldScale, center.y + 4 * shieldScale);
      ctx.lineTo(center.x, center.y + 14 * shieldScale);
      ctx.lineTo(center.x - 10 * shieldScale, center.y + 4 * shieldScale);
      ctx.closePath();
      ctx.fill();
      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 1.5;
      ctx.stroke();

      ctx.font = 'bold 12px "Cinzel", serif';
      ctx.fillStyle = '#48bb78';
      ctx.textAlign = 'center';
      ctx.fillText("PERFECT PARRY WINDOW! [SPACE]", center.x, center.y + 42);
    }
  }

  _drawFighter(fighter, isPlayer) {
    const ctx = this.ctx;
    const x = fighter.x;
    const y = fighter.y;

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.45)';
    ctx.beginPath();
    ctx.ellipse(x, y + 20, 28, 12, 0, 0, Math.PI * 2);
    ctx.fill();

    // Body
    ctx.fillStyle = isPlayer ? '#82201b' : '#2d3748';
    ctx.beginPath();
    ctx.arc(x, y, 22, 0, Math.PI * 2);
    ctx.fill();

    // Head / Helmet
    ctx.fillStyle = isPlayer ? '#d69e2e' : '#a0aec0';
    ctx.beginPath();
    ctx.arc(x, y - 10, 12, 0, Math.PI * 2);
    ctx.fill();

    // Weapon
    const dirFactor = isPlayer ? 1 : -1;
    const swordBase = { x: x + 16 * dirFactor, y: y + 5 };
    const swordTip = { x: x + 48 * dirFactor, y: y - 15 };

    ctx.strokeStyle = '#edf2f7';
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(swordBase.x, swordBase.y);
    ctx.lineTo(swordTip.x, swordTip.y);
    ctx.stroke();

    // Crossguard
    ctx.strokeStyle = '#d4af37';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(swordBase.x + 4 * dirFactor, swordBase.y - 8);
    ctx.lineTo(swordBase.x - 4 * dirFactor, swordBase.y + 8);
    ctx.stroke();

    // Health & Stamina Bars
    const barW = 80;
    const barH = 7;
    const barX = x - barW * 0.5;
    const barY = y - 48;

    // HP Bar
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    ctx.fillRect(barX, barY, barW, barH);
    ctx.fillStyle = isPlayer ? '#e53e3e' : '#dd6b20';
    ctx.fillRect(barX, barY, barW * (fighter.hp / fighter.maxHp), barH);

    // Stamina Bar
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    ctx.fillRect(barX, barY + 9, barW, 4);
    ctx.fillStyle = '#ecc94b';
    ctx.fillRect(barX, barY + 9, barW * (fighter.stamina / fighter.maxStamina), 4);

    // Label
    ctx.font = '11px "Cinzel", serif';
    ctx.fillStyle = '#ffffff';
    ctx.textAlign = 'center';
    ctx.fillText(isPlayer ? "Henry of Skalitz" : "Cuman Mercenary", x, barY - 6);
  }
}

window.KcdCombatSimulator = KcdCombatSimulator;
