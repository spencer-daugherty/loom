(function () {
  var header = document.querySelector('[data-site-header]');
  if (!header) return;

  var toggle = header.querySelector('[data-site-menu-toggle]');
  var panel = header.querySelector('#site-mobile-menu');
  var backdrop = header.querySelector('[data-site-menu-dismiss]');
  var label = toggle ? toggle.querySelector('[data-site-menu-label]') : null;
  var mobileQuery = window.matchMedia('(max-width: 980px)');

  function navigationSection() {
    var path = window.location.pathname.replace(/\/index\.html$/, '/');
    if (path.indexOf('/ambassadors/') === 0) return 'ambassadors';
    if (path === '/support.html' || path === '/privacy.html') return 'support';
    if (path.indexOf('/founding-member/') === 0) return 'pricing';
    if (path === '/' || path === '/landing.html' || path === '/splash.html') return '';
    return 'articles';
  }

  var currentSection = navigationSection();
  if (currentSection) {
    header.querySelectorAll('[data-nav-link="' + currentSection + '"]').forEach(function (link) {
      link.setAttribute('aria-current', 'page');
    });
  }

  if (!toggle || !panel) return;

  function setOpen(open, restoreFocus) {
    document.body.classList.toggle('site-menu-open', open);
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    toggle.setAttribute('aria-label', open ? 'Close navigation menu' : 'Open navigation menu');
    panel.setAttribute('aria-hidden', open ? 'false' : 'true');
    panel.inert = !open;
    if (label) label.textContent = open ? 'Close' : 'Menu';

    if (open) {
      window.requestAnimationFrame(function () {
        var firstLink = panel.querySelector('a');
        if (firstLink) firstLink.focus();
      });
    } else if (restoreFocus) {
      toggle.focus();
    }
  }

  setOpen(false, false);
  toggle.addEventListener('click', function () {
    setOpen(toggle.getAttribute('aria-expanded') !== 'true', false);
  });
  if (backdrop) backdrop.addEventListener('click', function () { setOpen(false, true); });
  panel.addEventListener('click', function (event) {
    if (event.target.closest('a')) setOpen(false, false);
  });
  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') setOpen(false, true);
  });
  mobileQuery.addEventListener('change', function (event) {
    if (!event.matches) setOpen(false, false);
  });
  window.addEventListener('pageshow', function () { setOpen(false, false); });
})();
