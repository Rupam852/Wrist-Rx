/* ════════════════════════════════════════════════════════════════
   Wrist Rx Landing Page JavaScript - Interactive Modals & Scroll
   Developed by Rupam Bairagya
   ════════════════════════════════════════════════════════════════ */

// Smooth Scroll to Section without updating URL address bar
function scrollToSection(sectionId) {
  const element = document.getElementById(sectionId);
  if (element) {
    element.scrollIntoView({ behavior: 'smooth', block: 'start' });
    if (history.pushState) {
      history.pushState(null, null, window.location.pathname);
    }
  }
}

// ── Hamburger Mobile Menu ─────────────────────────────────────────
function toggleMobileMenu() {
  const menu = document.getElementById('mobile-menu');
  const btn = document.getElementById('hamburger-btn');
  if (!menu) return;

  const isOpen = menu.classList.contains('open');
  if (isOpen) {
    closeMobileMenu();
  } else {
    menu.classList.add('open');
    btn && btn.classList.add('open');
  }
}

function closeMobileMenu() {
  const menu = document.getElementById('mobile-menu');
  const btn = document.getElementById('hamburger-btn');
  if (!menu) return;
  menu.classList.remove('open');
  btn && btn.classList.remove('open');
}

// Sticky Navbar Scroll Effect
window.addEventListener('scroll', () => {
  const navbar = document.getElementById('navbar');
  if (window.scrollY > 40) {
    navbar.classList.add('scrolled');
  } else {
    navbar.classList.remove('scrolled');
  }
});

// Modal Functions
function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.add('active');
    document.body.style.overflow = 'hidden';
  }
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.remove('active');
    document.body.style.overflow = 'auto';
  }
}

// Photo Preview Modal Function
function previewImage(src, name, role) {
  const modalSrc = document.getElementById('img-modal-src');
  const modalTitle = document.getElementById('img-modal-title');
  const modalSubtitle = document.getElementById('img-modal-subtitle');
  
  if (modalSrc && modalTitle && modalSubtitle) {
    modalSrc.src = src;
    modalTitle.textContent = name;
    modalSubtitle.textContent = role;
    openModal('img-modal-overlay');
  }
}

// Close Modal on Escape Keypress
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    closeMobileMenu();
    closeModal('img-modal-overlay');
    closeModal('privacy-modal');
    closeModal('terms-modal');
  }
});

// Intersection Observer for Smooth Scroll Reveal
document.addEventListener('DOMContentLoaded', () => {
  const revealElements = document.querySelectorAll('.reveal');
  
  const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('active');
      }
    });
  }, {
    root: null,
    threshold: 0.1,
    rootMargin: '0px 0px -40px 0px'
  });

  revealElements.forEach(el => revealObserver.observe(el));
});

// ── Copy Download Link ────────────────────────────────────────────────
function copyDownloadLink() {
  const url = 'https://neo-files-transfer.pages.dev/download/ad3a54a49ab4';
  const btn = document.getElementById('copy-btn');

  navigator.clipboard.writeText(url).then(() => {
    // Show copied state
    btn.classList.add('copied');
    btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`;

    // Reset after 2 seconds
    setTimeout(() => {
      btn.classList.remove('copied');
      btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>`;
    }, 2000);
  }).catch(() => {
    // Fallback for older browsers
    const el = document.createElement('textarea');
    el.value = url;
    document.body.appendChild(el);
    el.select();
    document.execCommand('copy');
    document.body.removeChild(el);
  });
}
