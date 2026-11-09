/**
 * Kingdom Come: Deliverance - Main Page Logic & Codex Interactivity
 */
document.addEventListener('DOMContentLoaded', () => {
  // Initialize simulators
  if (window.KcdCombatSimulator) {
    new window.KcdCombatSimulator('combatCanvas');
  }

  if (window.KcdLockpickSimulator) {
    const lockpickSim = new window.KcdLockpickSimulator('lockpickCanvas');
    const resetBtn = document.getElementById('resetLockpickBtn');
    if (resetBtn) {
      resetBtn.addEventListener('click', () => {
        lockpickSim.picksLeft = 5;
        lockpickSim._reset();
      });
    }
  }

  // Audio Toggle Button
  const audioBtn = document.getElementById('audioToggleBtn');
  if (audioBtn && window.medievalAudio) {
    audioBtn.addEventListener('click', () => {
      const isPlaying = window.medievalAudio.toggleSound();
      audioBtn.classList.toggle('playing', isPlaying);
      audioBtn.innerHTML = isPlaying 
        ? '<span>🔊</span> <span>Mute Lute & Campfire</span>' 
        : '<span>🎵</span> <span>Play Medieval Ambience</span>';
    });
  }

  // Background Ember Particles
  const bgCanvas = document.getElementById('bgParticlesCanvas');
  if (bgCanvas) {
    const ctx = bgCanvas.getContext('2d');
    let width = bgCanvas.width = window.innerWidth;
    let height = bgCanvas.height = window.innerHeight;

    window.addEventListener('resize', () => {
      width = bgCanvas.width = window.innerWidth;
      height = bgCanvas.height = window.innerHeight;
    });

    const embers = [];
    for (let i = 0; i < 45; i++) {
      embers.push({
        x: Math.random() * width,
        y: Math.random() * height,
        speed: 15 + Math.random() * 45,
        drift: (Math.random() - 0.5) * 20,
        radius: 1 + Math.random() * 2.2,
        opacity: 0.2 + Math.random() * 0.6
      });
    }

    let lastT = performance.now();
    function animateParticles(now) {
      const dt = (now - lastT) / 1000;
      lastT = now;

      ctx.clearRect(0, 0, width, height);

      embers.forEach((em) => {
        em.y -= em.speed * dt;
        em.x += Math.sin(em.y * 0.015) * em.drift * dt;
        if (em.y < -10) {
          em.y = height + 10;
          em.x = Math.random() * width;
        }

        ctx.fillStyle = `rgba(246, 173, 85, ${em.opacity})`;
        ctx.beginPath();
        ctx.arc(em.x, em.y, em.radius, 0, Math.PI * 2);
        ctx.fill();
      });

      requestAnimationFrame(animateParticles);
    }
    requestAnimationFrame(animateParticles);
  }

  // Codex Tab Switching
  const codexTabs = document.querySelectorAll('.codex-tab-btn');
  const codexPanels = document.querySelectorAll('.codex-panel');

  codexTabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      codexTabs.forEach((t) => t.classList.remove('active'));
      codexPanels.forEach((p) => p.classList.remove('active'));

      tab.classList.add('active');
      const targetId = tab.dataset.target;
      const targetPanel = document.getElementById(targetId);
      if (targetPanel) {
        targetPanel.classList.add('active');
        if (window.medievalAudio) window.medievalAudio.playPluckedString(330, 0.2);
      }
    });
  });
});
