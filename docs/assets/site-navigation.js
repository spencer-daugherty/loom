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
        article_slug: appStoreLink.dataset.contentSlug || '',
        position_id: appStoreLink.dataset.positionId || '',
        cta_placement: appStoreLink.dataset.ctaPosition || '',
        destination: appStoreLink.dataset.destination || 'app_store',
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
        link_position: articleLink.dataset.linkPosition || '',
        article_slug: articleLink.dataset.sourceSlug || '',
        position_id: articleLink.dataset.positionId || '',
        cta_placement: articleLink.dataset.linkPosition || '',
        destination: articleLink.dataset.destination || articleLink.getAttribute('href') || ''
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

  function currentFragmentTarget() {
    if (!window.location.hash || window.location.hash.length < 2) return null;
    try {
      return document.getElementById(decodeURIComponent(window.location.hash.slice(1)));
    } catch (error) {
      return document.getElementById(window.location.hash.slice(1));
    }
  }

  /* Long pages that opt into smooth scrolling can leave a direct fragment entry
     visibly travelling for several seconds. Settle the initial target immediately,
     after layout is known, while preserving smooth scrolling for in-page clicks. */
  var initialFragmentTarget = currentFragmentTarget();
  if (initialFragmentTarget) {
    var settleInitialFragment = function () {
      var previousScrollBehavior = document.documentElement.style.scrollBehavior;
      document.documentElement.style.scrollBehavior = 'auto';
      initialFragmentTarget.scrollIntoView({ block: 'start', inline: 'nearest' });
      document.documentElement.style.scrollBehavior = previousScrollBehavior;
    };
    window.requestAnimationFrame(function () {
      window.requestAnimationFrame(settleInitialFragment);
    });
    window.addEventListener('load', settleInitialFragment, { once: true });
  }

  function siteMotionMode() {
    var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var slowUpdate = window.matchMedia('(update: slow)').matches;
    var connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
    var savesData = Boolean(connection && connection.saveData);
    var memory = Number(navigator.deviceMemory || 0);
    var cores = Number(navigator.hardwareConcurrency || 0);

    if (reducedMotion || slowUpdate || savesData || !('IntersectionObserver' in window)) return 'off';

    /* Safari may deliberately report a small processor count on capable iPhones.
       Only downgrade when the browser also exposes a genuinely low memory signal. */
    if (memory && (memory <= 2 || (memory <= 4 && cores && cores <= 2))) return 'lite';
    return 'full';
  }

  function setupSiteMotion() {
    var path = window.location.pathname.replace(/\/index\.html$/, '/');
    if (path === '/') return;

    var mode = siteMotionMode();
    document.documentElement.dataset.motionMode = mode;
    document.documentElement.classList.add('site-motion-' + mode);
    if (mode === 'off') return;

    var targets = Array.from(document.querySelectorAll([
      'main > header',
      'main > section',
      'main > article',
      'main > .shell > section',
      '[data-site-motion]'
    ].join(','))).filter(function (target, index, allTargets) {
      return allTargets.indexOf(target) === index;
    }).slice(0, 28);

    if (!targets.length) return;

    targets.forEach(function (target, targetIndex) {
      target.classList.add('site-motion-item');
      target.style.setProperty('--site-motion-delay', targetIndex === 0 ? '30ms' : '0ms');

      if (mode !== 'full') return;
      Array.from(target.querySelectorAll('.grid > .card, .card-grid > .card'))
        .slice(0, 8)
        .forEach(function (child, childIndex) {
          child.classList.add('site-motion-child');
          child.style.setProperty('--site-motion-child-delay', (90 + (childIndex * 55)) + 'ms');
        });
    });

    function playSiteEntrance(target) {
      if (target.classList.contains('is-visible')) return;
      target.classList.add('is-visible');

      if (typeof target.animate !== 'function') return;
      var full = mode === 'full';
      target.animate(
        full
          ? [
              { opacity: 0.72, transform: 'translate3d(0, 14px, 0)' },
              { opacity: 1, transform: 'translate3d(0, 0, 0)' }
            ]
          : [{ opacity: 0.82 }, { opacity: 1 }],
        {
          duration: full ? 560 : 220,
          delay: Number.parseInt(target.style.getPropertyValue('--site-motion-delay'), 10) || 0,
          easing: 'cubic-bezier(0.2, 0.8, 0.2, 1)',
          fill: 'none'
        }
      );

      if (!full) return;
      Array.from(target.querySelectorAll('.site-motion-child')).forEach(function (child, childIndex) {
        if (typeof child.animate !== 'function') return;
        child.animate(
          [
            { opacity: 0.7, transform: 'translate3d(0, 10px, 0) scale(0.992)' },
            { opacity: 1, transform: 'translate3d(0, 0, 0) scale(1)' }
          ],
          {
            duration: 520,
            delay: 80 + (childIndex * 55),
            easing: 'cubic-bezier(0.2, 0.8, 0.2, 1)',
            fill: 'none'
          }
        );
      });
    }

    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        playSiteEntrance(entry.target);
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.01, rootMargin: '0px 0px -6% 0px' });

    document.documentElement.classList.add('site-motion-ready');
    window.requestAnimationFrame(function () {
      window.requestAnimationFrame(function () {
        targets.forEach(function (target) { observer.observe(target); });
      });
    });

    var fragmentTarget = currentFragmentTarget();
    if (fragmentTarget) {
      targets.forEach(function (target) {
        if (target === fragmentTarget || target.contains(fragmentTarget) || fragmentTarget.contains(target)) {
          playSiteEntrance(target);
          observer.unobserve(target);
        }
      });
    }

    window.setTimeout(function () {
      targets.forEach(function (target) {
        if (target.classList.contains('is-visible')) return;
        playSiteEntrance(target);
        observer.unobserve(target);
      });
    }, 1400);

    window.matchMedia('(prefers-reduced-motion: reduce)').addEventListener?.('change', function (event) {
      if (!event.matches) return;
      targets.forEach(function (target) { target.classList.add('is-visible'); });
      observer.disconnect();
    });
  }

  setupSiteMotion();

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
    if (path === '/support.html') return 'support';
    if (path.indexOf('/founding-member/') === 0) return 'pricing';
    if (path === '/articles/' || path.indexOf('/articles/') === 0) return 'articles';
    if (path === '/' || path === '/landing.html' || path === '/splash.html') return '';
    return '';
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
    document.querySelectorAll('main, footer').forEach(function (region) {
      region.inert = open;
    });
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
    if (toggle.getAttribute('aria-expanded') !== 'true') return;
    if (event.key === 'Escape') {
      setOpen(false, true);
      return;
    }
    if (event.key !== 'Tab') return;

    var focusable = [toggle].concat(Array.from(panel.querySelectorAll('a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])')))
      .filter(function (element) { return !element.inert && element.getClientRects().length > 0; });
    if (!focusable.length) return;
    var first = focusable[0];
    var last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  });
  mobileQuery.addEventListener('change', function (event) {
    if (!event.matches) setOpen(false, false);
  });
  window.addEventListener('pageshow', function () { setOpen(false, false); });
})();
