(function () {
  document.addEventListener('click', function (event) {
    var appStoreLink = event.target.closest('[data-app-store-cta]');
    if (
      appStoreLink &&
      (
        appStoreLink.dataset.contentSlug ||
        appStoreLink.dataset.contentCluster ||
        appStoreLink.dataset.searchIntent
      ) &&
      typeof window.gtag === 'function'
    ) {
      window.gtag('event', 'app_store_click', {
        page_type: appStoreLink.dataset.pageType || '',
        content_slug: appStoreLink.dataset.contentSlug || '',
        content_cluster: appStoreLink.dataset.contentCluster || '',
        target_keyword: appStoreLink.dataset.targetKeyword || '',
        search_intent: appStoreLink.dataset.searchIntent || '',
        cta_position: appStoreLink.dataset.ctaPosition || '',
        destination: 'app_store',
        transport_type: 'beacon',
        event_timeout: 2000
      });
    }

    var articleLink = event.target.closest('[data-article-link]');
    if (articleLink && typeof window.gtag === 'function') {
      window.gtag('event', 'article_link_click', {
        source_slug: articleLink.dataset.sourceSlug || '',
        destination_slug: articleLink.dataset.destinationSlug || '',
        content_cluster: articleLink.dataset.contentCluster || '',
        link_position: articleLink.dataset.linkPosition || ''
      });
    }
  });

  if (typeof window.gtag === 'function' && document.referrer) {
    try {
      var referralHost = new URL(document.referrer).hostname.toLowerCase();
      var aiReferralSources = [
        { match: 'chatgpt.com', source: 'chatgpt' },
        { match: 'perplexity.ai', source: 'perplexity' },
        { match: 'claude.ai', source: 'claude' },
        { match: 'gemini.google.com', source: 'gemini' },
        { match: 'copilot.microsoft.com', source: 'microsoft-copilot' }
      ];
      var aiReferral = aiReferralSources.find(function (candidate) {
        return referralHost === candidate.match || referralHost.endsWith('.' + candidate.match);
      });
      if (aiReferral) {
        window.gtag('event', 'ai_referral_landing', {
          ai_source: aiReferral.source,
          landing_path: window.location.pathname
        });
      }
    } catch (error) {}
  }

  var header = document.querySelector('[data-site-header]');
  if (!header) return;

  var toggle = header.querySelector('[data-site-menu-toggle]');
  var panel = header.querySelector('#site-mobile-menu');
  var backdrop = header.querySelector('[data-site-menu-dismiss]');
  var label = toggle ? toggle.querySelector('[data-site-menu-label]') : null;
  var mobileQuery = window.matchMedia('(max-width: 980px)');
  var ambassadorBanner = document.querySelector('[data-ambassador-banner-link]');
  var ambassadorBannerDismiss = document.querySelector('[data-ambassador-banner-dismiss]');

  if (ambassadorBannerDismiss) {
    ambassadorBannerDismiss.addEventListener('click', function () {
      document.documentElement.classList.add('ambassador-banner-dismissed');
      try {
        window.localStorage.setItem('loom-ambassador-banner-dismissed-open-v2', '1');
      } catch (error) {}
      if (typeof window.gtag === 'function') window.gtag('event', 'ambassador_banner_dismiss', { page_type: 'homepage' });
    });
  }

  if (ambassadorBanner) {
    ambassadorBanner.addEventListener('click', function () {
      if (typeof window.gtag === 'function') window.gtag('event', 'ambassador_banner_click', { page_type: 'homepage' });
    });
  }

  function navigationSection() {
    var path = window.location.pathname.replace(/\/index\.html$/, '/');
    if (path.indexOf('/ambassadors/') === 0) return 'ambassadors';
    if (path === '/support.html' || path === '/privacy.html') return 'support';
    if (path.indexOf('/founding-member/') === 0) return 'pricing';
    if (path.indexOf('/investor/') === 0) return '';
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
