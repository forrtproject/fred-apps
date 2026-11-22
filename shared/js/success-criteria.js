/**
 * FReD Static Apps - Success Criteria Definitions
 *
 * Mirrors the R implementation in replication_outcomes.R
 * Note: Client-side calculations are only for reference/validation.
 * The preprocessed JSON should have all outcomes pre-computed.
 */

window.FReD = window.FReD || {};

FReD.successCriteria = {
  // Criterion definitions
  criteria: {
    significance_r: {
      id: 'significance_r',
      label: 'Significance of Replication',
      shortLabel: 'Significance (Rep)',
      hasOSNotSignificant: true,
      note: 'Replication success was assessed based on the statistical significance of the replication effect (using reported p-values, falling back to effect-size-derived p-values when unavailable or indeterminate) and whether its direction is consistent with the original effect. Replications that were significant and in the same direction as the original were considered as successes, while replications that were not significant or in the opposite direction were considered as failures.',
      hasDynamicReversalNote: true
    },
    significance_agg: {
      id: 'significance_agg',
      label: 'Aggregated Significance',
      shortLabel: 'Aggregated Sig',
      hasOSNotSignificant: false,
      note: 'Replication success was assessed based on the aggregation of effect sizes from the original and replication studies using a meta-analytic approach. Replications where the combined effect was significantly different from zero were considered as successes, while those where the combined effect was not significant were considered as failures.'
    },
    consistency_ci: {
      id: 'consistency_ci',
      label: 'Consistency with CI',
      shortLabel: 'Consistency (CI)',
      hasOSNotSignificant: false,
      note: 'Replication success was assessed based on whether the original effect size fell within the confidence interval of the replication effect size. Replications where the original effect size was within the confidence interval were considered as successes, while those where it was outside were considered as failures.'
    },
    consistency_pi: {
      id: 'consistency_pi',
      label: 'Consistency with PI',
      shortLabel: 'Consistency (PI)',
      hasOSNotSignificant: false,
      note: 'Replication success was assessed based on whether the replication effect size fell within the prediction interval derived from the original study and replication sample size. Replications within the prediction interval were considered as successes, while those outside the prediction interval were considered as failures.'
    },
    homogeneity: {
      id: 'homogeneity',
      label: 'Homogeneity',
      shortLabel: 'Homogeneity',
      hasOSNotSignificant: false,
      note: 'Replication success was assessed based on the homogeneity of the effects from the original and replication studies using a heterogeneity test (Q-test). Replications where the effects were homogeneous were considered as successes, while those that showed heterogeneity were considered as failures.'
    },
    homogeneity_significance: {
      id: 'homogeneity_significance',
      label: 'Homogeneity & Significance',
      shortLabel: 'Homog. & Sig',
      hasOSNotSignificant: true,
      note: 'Replication success was assessed based on the combination of homogeneity and the significance of the effect sizes. Replications where the effects were homogeneous and jointly significantly different from zero were considered as successes, while those that were either not homogeneous or not significantly different from zero were considered as failures.'
    },
    small_telescopes: {
      id: 'small_telescopes',
      label: 'Small Telescopes',
      shortLabel: 'Small Telescopes',
      hasOSNotSignificant: false,
      note: 'Replication success was assessed based on whether the replication effect size was larger than the effect size that would have given the original study a power of 33%. Replications that met this criterion were considered as successes, while those that did not were considered as failures.'
    },
    reported_success: {
      id: 'reported_success',
      label: 'Reported Success',
      shortLabel: 'Reported',
      hasOSNotSignificant: false,
      note: 'Replication success was assessed based on how the replication authors described their results, as coded in the FReD database. Where this coding is missing, the calculated outcome stored in the database is used instead.'
    }
  },

  // Color mapping for outcomes
  colors: {
    // Common outcomes
    'success': '#8FBC8F',
    'Success': '#8FBC8F',
    'failure': '#FF7F7F',
    'Failure': '#FF7F7F',
    'failure (reversal)': 'darkred',
    'Failure (reversal)': 'darkred',
    'OS not significant': '#D3D3D3',
    'Not calculable': '#C8C8C8',
    'not calculable': '#C8C8C8',

    // Reported success outcomes (from FReD/FLoRA)
    'successful': '#8FBC8F',
    'Successful': '#8FBC8F',
    'successful replication': '#8FBC8F',
    'Successful replication': '#8FBC8F',
    'failed': '#FF7F7F',
    'Failed': '#FF7F7F',
    'failed replication': '#FF7F7F',
    'Failed replication': '#FF7F7F',
    'mixed': '#FFD700',
    'Mixed': '#FFD700',
    'informative failure': '#FF7F7F',
    'Informative failure': '#FF7F7F',
    'uninformative': '#D3D3D3',
    'Uninformative': '#D3D3D3',
    'descriptive only': '#B0C4DE',
    'Descriptive only': '#B0C4DE',
    'statistically successful but flawed': '#d88201',
    'Statistically successful but flawed': '#d88201',

    // Homogeneity & significance specific
    'success (homogeneous and jointly significantly above 0)': '#8FBC8F',
    'Success (homogeneous and jointly significantly above 0)': '#8FBC8F',
    'failure (not homogeneous but jointly significantly above 0)': '#efa986',
    'Failure (not homogeneous but jointly significantly above 0)': '#efa986',
    'failure (not homogeneous and not significant)': 'darkred',
    'Failure (not homogeneous and not significant)': 'darkred',
    'failure (homogeneous but not significant)': '#FF7F7F',
    'Failure (homogeneous but not significant)': '#FF7F7F'
  },

  // Rug plot colors (significance indicators)
  rugColors: {
    significant: '#4DCCD0',
    notSignificant: '#FA948C'
  },

  /**
   * Get color for an outcome label
   */
  getColor(outcome) {
    if (!outcome) return this.colors['Not calculable'];
    return this.colors[outcome] || this.colors[outcome.toLowerCase()] || this.colors['Not calculable'];
  },

  /**
   * Get colors for a specific criterion
   */
  getColorsForCriterion(criterionId) {
    const criterion = this.criteria[criterionId];
    if (!criterion) return {};

    const colors = {
      'success': this.colors['success'],
      'Success': this.colors['Success'],
      'failure': this.colors['failure'],
      'Failure': this.colors['Failure'],
      'Not calculable': this.colors['Not calculable']
    };

    // Add criterion-specific colors
    if (criterion.hasOSNotSignificant) {
      colors['OS not significant'] = this.colors['OS not significant'];
    }

    if (criterionId === 'significance_r' || criterionId === 'significance_agg') {
      colors['failure (reversal)'] = this.colors['failure (reversal)'];
      colors['Failure (reversal)'] = this.colors['Failure (reversal)'];
    }

    if (criterionId === 'homogeneity_significance') {
      Object.assign(colors, {
        'success (homogeneous and jointly significantly above 0)': this.colors['success (homogeneous and jointly significantly above 0)'],
        'Success (homogeneous and jointly significantly above 0)': this.colors['Success (homogeneous and jointly significantly above 0)'],
        'failure (not homogeneous but jointly significantly above 0)': this.colors['failure (not homogeneous but jointly significantly above 0)'],
        'Failure (not homogeneous but jointly significantly above 0)': this.colors['Failure (not homogeneous but jointly significantly above 0)'],
        'failure (not homogeneous and not significant)': this.colors['failure (not homogeneous and not significant)'],
        'Failure (not homogeneous and not significant)': this.colors['Failure (not homogeneous and not significant)'],
        'failure (homogeneous but not significant)': this.colors['failure (homogeneous but not significant)'],
        'Failure (homogeneous but not significant)': this.colors['Failure (homogeneous but not significant)']
      });
    }

    // Add reported success colors
    if (criterionId === 'reported_success') {
      Object.assign(colors, {
        'successful': this.colors['successful'],
        'Successful': this.colors['Successful'],
        'successful replication': this.colors['successful replication'],
        'Successful replication': this.colors['Successful replication'],
        'failed': this.colors['failed'],
        'Failed': this.colors['Failed'],
        'failed replication': this.colors['failed replication'],
        'Failed replication': this.colors['Failed replication'],
        'OS not significant': this.colors['OS not significant'],
        'mixed': this.colors['mixed'],
        'Mixed': this.colors['Mixed'],
        'informative failure': this.colors['informative failure'],
        'Informative failure': this.colors['Informative failure'],
        'uninformative': this.colors['uninformative'],
        'Uninformative': this.colors['Uninformative'],
        'descriptive only': this.colors['descriptive only'],
        'Descriptive only': this.colors['Descriptive only'],
        'statistically successful but flawed': this.colors['statistically successful but flawed'],
        'Statistically successful but flawed': this.colors['Statistically successful but flawed']
      });
    }

    return colors;
  },

  /**
   * Get outcome for a study based on pre-computed data
   */
  getOutcome(study, criterionId) {
    if (!study || !study.outcomes) {
      return { outcome: 'Not calculable', outcomeReport: 'Not calculable', color: this.colors['Not calculable'] };
    }

    // Special case for reported_success
    if (criterionId === 'reported_success') {
      const result = study.reported_success || study.result || 'Not calculable';
      return {
        outcome: result,
        outcomeReport: result,
        color: this.getColor(result)
      };
    }

    const outcomeData = study.outcomes[criterionId];
    if (!outcomeData) {
      return { outcome: 'Not calculable', outcomeReport: 'Not calculable', color: this.colors['Not calculable'] };
    }

    const rawOutcome = outcomeData.outcome;
    let rawReport = outcomeData.outcome_report;
    // Normalize legacy FReD "not coded" placeholder when a computed criterion cannot be evaluated
    if (!rawOutcome && rawReport && rawReport.toLowerCase() === 'not coded') {
      rawReport = null;
    }

    const outcome = rawOutcome || 'Not calculable';
    const outcomeReport = rawReport || outcome;

    return {
      outcome,
      outcomeReport,
      color: this.getColor(outcomeReport)
    };
  },

  /**
   * Calculate two-tailed p-value from correlation r and sample size N (mirrors FReD::p_from_r)
   */
  pFromR(r, n) {
    if (r === null || r === undefined || n === null || n === undefined || r === '' || n === '') return null;
    const rNum = Number(r);
    const nNum = Number(n);
    if (!Number.isFinite(rNum) || !Number.isFinite(nNum) || nNum <= 2 || Math.abs(rNum) > 1) return null;
    if (Math.abs(rNum) === 1) return 0;
    const df = nNum - 2;
    const t = rNum * Math.sqrt(df / (1 - rNum * rNum));
    const x = df / (df + t * t);
    return this._betaInc(df / 2, 0.5, x);
  },

  /**
   * Regularized incomplete beta function I_x(a, b) via Lentz's continued fraction
   */
  _betaInc(a, b, x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    const bt = Math.exp(
      this._logGamma(a + b) - this._logGamma(a) - this._logGamma(b) +
      a * Math.log(x) + b * Math.log(1 - x)
    );
    if (x < (a + 1) / (a + b + 2)) {
      return bt * this._betaCF(a, b, x) / a;
    }
    return 1 - bt * this._betaCF(b, a, 1 - x) / b;
  },

  /**
   * Continued fraction evaluation for regularized incomplete beta (Numerical Recipes / Lentz)
   */
  _betaCF(a, b, x) {
    const MAXIT = 200;
    const EPS = 3e-12;
    const FPMIN = 1e-300;
    const qab = a + b;
    const qap = a + 1;
    const qam = a - 1;
    let c = 1;
    let d = 1 - qab * x / qap;
    if (Math.abs(d) < FPMIN) d = FPMIN;
    d = 1 / d;
    let h = d;
    for (let m = 1; m <= MAXIT; m++) {
      const m2 = 2 * m;
      let aa = m * (b - m) * x / ((qam + m2) * (a + m2));
      d = 1 + aa * d;
      if (Math.abs(d) < FPMIN) d = FPMIN;
      c = 1 + aa / c;
      if (Math.abs(c) < FPMIN) c = FPMIN;
      d = 1 / d;
      h *= d * c;
      aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
      d = 1 + aa * d;
      if (Math.abs(d) < FPMIN) d = FPMIN;
      c = 1 + aa / c;
      if (Math.abs(c) < FPMIN) c = FPMIN;
      d = 1 / d;
      const del = d * c;
      h *= del;
      if (Math.abs(del - 1) < EPS) break;
    }
    return h;
  },

  /**
   * Lanczos approximation for ln(Gamma(z))
   */
  _logGamma(z) {
    const cof = [
      76.18009172947146, -86.50532032941677, 24.01409824083091,
      -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5
    ];
    let x = z;
    let y = z;
    let tmp = x + 5.5;
    tmp -= (x + 0.5) * Math.log(tmp);
    let ser = 1.000000000190015;
    for (let j = 0; j < cof.length; j++) {
      ser += cof[j] / ++y;
    }
    return -tmp + Math.log(2.5066282746310005 * ser / x);
  },

  /**
   * Normal CDF approximation
   */
  _normalCDF(x) {
    const a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741;
    const a4 = -1.453152027, a5 = 1.061405429, p = 0.3275911;
    const sign = x < 0 ? -1 : 1;
    x = Math.abs(x) / Math.sqrt(2);
    const t = 1 / (1 + p * x);
    const y = 1 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Math.exp(-x * x);
    return 0.5 * (1 + sign * y);
  },

  /**
   * Get all available criteria as array
   */
  getCriteriaList() {
    return Object.values(this.criteria);
  },

  /**
   * Get criterion by ID
   */
  getCriterion(id) {
    return this.criteria[id] || null;
  },

  /**
   * Check if a study's direction is assessable
   * (has directional effect type and both effect sizes)
   */
  isDirectionAssessable(study) {
    return study && study.direction_assessable === true;
  },

  /**
   * Count successes where direction cannot be assessed
   * (these could potentially be reversals that we can't detect)
   * @param {Array} studies - Array of study objects
   * @param {string} criterionId - The criterion to check (only relevant for significance_r)
   * @returns {Object} { successCount, nonAssessableCount }
   */
  countNonAssessableSuccesses(studies, criterionId) {
    if (criterionId !== 'significance_r') {
      return { successCount: 0, nonAssessableCount: 0 };
    }

    let successCount = 0;
    let nonAssessableCount = 0;

    studies.forEach(study => {
      const { outcome } = this.getOutcome(study, criterionId);
      // Check for success (case-insensitive)
      if (outcome && outcome.toLowerCase() === 'success') {
        successCount++;
        // If direction is not assessable, we can't distinguish from reversal
        if (!this.isDirectionAssessable(study)) {
          nonAssessableCount++;
        }
      }
    });

    return { successCount, nonAssessableCount };
  }
};

window.FReD = FReD;
