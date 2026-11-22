/**
 * FReD Explorer - URL State Management
 *
 * Handles syncing filter state with URL parameters for shareable links
 */

window.FReD = window.FReD || {};

FReD.state = {
  // Valid navigation tab IDs
  VALID_TABS: ['overview', 'forest', 'correlates', 'data'],

  // Default state
  defaults: {
    source: 'All studies',
    minPower: 0,
    criterion: 'significance_r',
    search: '',
    tab: 'overview'
  },

  // Current state
  current: {},

  // Listeners for state changes
  listeners: [],

  /**
   * Initialize state from URL or defaults
   */
  init() {
    this.current = { ...this.defaults };
    this.loadFromURL();

    // Listen for browser back/forward
    window.addEventListener('popstate', () => {
      const prev = { ...this.current };
      this.current = { ...this.defaults };
      this.loadFromURL();
      const changes = {};
      Object.keys(this.current).forEach((k) => {
        if (this.current[k] !== prev[k]) changes[k] = this.current[k];
      });
      this.notifyListeners(Object.keys(changes).length ? changes : this.current);
    });
  },

  /**
   * Load state from URL parameters
   */
  loadFromURL() {
    const params = FReD.utils.parseQueryParams();

    if (params.source) {
      this.current.source = params.source;
    }
    if (params.power !== undefined) {
      const power = parseFloat(params.power);
      if (!isNaN(power) && power >= 0 && power <= 0.99) {
        this.current.minPower = Math.round(power * 100) / 100;
      }
    }
    if (params.criterion && FReD.successCriteria.criteria[params.criterion]) {
      this.current.criterion = params.criterion;
    }
    if (params.search) {
      this.current.search = params.search;
    }
    if (params.tab && this.VALID_TABS.includes(params.tab)) {
      this.current.tab = params.tab;
    }
  },

  /**
   * Save current state to URL
   */
  saveToURL(pushHistory = false) {
    // Include all state keys - use null for defaults to trigger deletion
    // Exception: criterion is always shown for transparency
    const params = {
      source: this.current.source !== this.defaults.source ? this.current.source : null,
      power: this.current.minPower !== this.defaults.minPower ? this.current.minPower : null,
      criterion: this.current.criterion,  // Always show criterion for transparency
      search: this.current.search !== this.defaults.search ? this.current.search : null,
      tab: this.current.tab !== this.defaults.tab ? this.current.tab : null
    };

    FReD.utils.updateQueryParams(params, pushHistory);
  },

  /**
   * Get current state
   */
  get(key) {
    return key ? this.current[key] : { ...this.current };
  },

  /**
   * Set state value(s)
   */
  set(keyOrObj, value) {
    const changes = typeof keyOrObj === 'string'
      ? { [keyOrObj]: value }
      : keyOrObj;

    let hasChanges = false;
    let tabChanged = false;
    Object.entries(changes).forEach(([k, v]) => {
      if (k === 'tab' && !this.VALID_TABS.includes(v)) return;
      if (this.current[k] !== v) {
        this.current[k] = v;
        hasChanges = true;
        if (k === 'tab') tabChanged = true;
      }
    });

    if (hasChanges) {
      this.saveToURL(tabChanged);
      this.notifyListeners(changes);
    }
  },

  /**
   * Reset to defaults
   */
  reset() {
    this.current = { ...this.defaults };
    this.saveToURL();
    this.notifyListeners(this.defaults);
  },

  /**
   * Add state change listener
   */
  onChange(callback) {
    this.listeners.push(callback);
    return () => {
      this.listeners = this.listeners.filter(l => l !== callback);
    };
  },

  /**
   * Notify all listeners of state change
   */
  notifyListeners(changes = this.current) {
    this.listeners.forEach(callback => {
      try {
        callback(changes, this.current);
      } catch (err) {
        console.error('State listener error:', err);
      }
    });
  },

  /**
   * Get shareable URL for current state
   */
  getShareableURL() {
    return window.location.href;
  }
};

window.FReD = FReD;
