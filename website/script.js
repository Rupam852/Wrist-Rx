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
    closeModal('img-modal-overlay');
    closeModal('privacy-modal');
    closeModal('terms-modal');
  }
});
