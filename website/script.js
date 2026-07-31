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
