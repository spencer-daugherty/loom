(function () {
  'use strict';

  var measurementId = 'G-XTL8BKQYPW';
  var optOutCookie = 'loom_analytics_opt_out';
  var optOutStorageKey = 'loom.analytics.opt_out';
  var controlParameter = 'loom_internal';
  var productionHosts = ['loomlife.us', 'www.loomlife.us'];

  function isProductionSite() {
    return window.location.protocol === 'https:' &&
      productionHosts.indexOf(window.location.hostname.toLowerCase()) !== -1;
  }

  function isAutomatedBrowser() {
    return Boolean(window.navigator && window.navigator.webdriver);
  }

  function hasOptOutCookie() {
    return document.cookie.split(';').some(function (cookie) {
      return cookie.trim() === optOutCookie + '=1';
    });
  }

  function hasOptOutStorage() {
    try {
      return window.localStorage.getItem(optOutStorageKey) === '1';
    } catch (error) {
      return false;
    }
  }

  function setInternalBrowser(isInternal) {
    try {
      if (isInternal) {
        window.localStorage.setItem(optOutStorageKey, '1');
      } else {
        window.localStorage.removeItem(optOutStorageKey);
      }
    } catch (error) {
      // Cookies provide the fallback when browser storage is unavailable.
    }

    var cookie = optOutCookie + '=' + (isInternal ? '1' : '') +
      '; Max-Age=' + (isInternal ? '63072000' : '0') +
      '; Path=/; SameSite=Lax';

    if (window.location.protocol === 'https:') {
      cookie += '; Secure';
    }
    if (productionHosts.indexOf(window.location.hostname.toLowerCase()) !== -1) {
      cookie += '; Domain=loomlife.us';
    }

    document.cookie = cookie;
  }

  function applyControlParameter() {
    try {
      var url = new URL(window.location.href);
      var value = url.searchParams.get(controlParameter);

      if (value !== '1' && value !== '0') {
        return null;
      }

      var isInternal = value === '1';
      setInternalBrowser(isInternal);
      url.searchParams.delete(controlParameter);
      window.history.replaceState(
        window.history.state,
        '',
        url.pathname + url.search + url.hash
      );
      return isInternal;
    } catch (error) {
      return null;
    }
  }

  var controlledOptOut = applyControlParameter();
  var isInternal = controlledOptOut === null
    ? hasOptOutCookie() || hasOptOutStorage()
    : controlledOptOut;
  var productionSite = isProductionSite();
  var automatedBrowser = isAutomatedBrowser();
  var disabled = !productionSite || isInternal || automatedBrowser;
  var disabledReason = !productionSite
    ? 'non-production'
    : isInternal
      ? 'internal-browser'
      : automatedBrowser
        ? 'automated-browser'
        : null;

  window['ga-disable-' + measurementId] = disabled;
  window.dataLayer = window.dataLayer || [];
  window.gtag = function () {
    if (!window['ga-disable-' + measurementId]) {
      window.dataLayer.push(arguments);
    }
  };

  window.LoomAnalytics = {
    disabled: disabled,
    disabledReason: disabledReason,
    measurementId: measurementId,
    setInternalBrowser: function (internal) {
      setInternalBrowser(Boolean(internal));
      window.location.reload();
    }
  };

  if (disabled) {
    return;
  }

  var script = document.createElement('script');
  script.async = true;
  script.src = 'https://www.googletagmanager.com/gtag/js?id=' +
    encodeURIComponent(measurementId);
  document.head.appendChild(script);

  window.gtag('js', new Date());
  window.gtag('config', measurementId);
}());
