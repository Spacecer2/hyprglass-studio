import {
  createDefaultState,
  decorationFields,
  defaultWindowRules,
  formatConf,
  formatLua,
  globalFields,
  layerFields,
  parseCommaList,
  presetOptions,
  serializeTintState,
  summarizeState,
  themeFields,
  themeOptions,
} from './schema.js';

const STORAGE_KEY = 'hyprglass-studio.state.v1';
const app = document.getElementById('app');
const loadErrorBanner = document.getElementById('load-error');

const caughtErrors = [];
let syntaxStatus = { ok: null, message: '' };

window.addEventListener('error', (event) => {
  const message = event.error?.message || event.message || 'Unknown error';
  caughtErrors.push({ type: 'error', message, time: Date.now() });
  showError('Runtime error', message);
  if (loadErrorBanner) loadErrorBanner.hidden = false;
});

window.addEventListener('unhandledrejection', (event) => {
  const reason = event.reason;
  const message = reason instanceof Error ? reason.message : String(reason || 'Unhandled rejection');
  caughtErrors.push({ type: 'rejection', message, time: Date.now() });
  showError('Unhandled promise rejection', message);
  if (loadErrorBanner) loadErrorBanner.hidden = false;
});

const savedState = loadState();
let state = savedState.state;
let activeSection = savedState.activeSection || 'global';
let isApplying = false;
let pendingConfirm = null;

render();
wireEvents();
persist();

if (loadErrorBanner) loadErrorBanner.hidden = true;

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { state: createDefaultState(), activeSection: 'global' };
    const parsed = JSON.parse(raw);
    return {
      state: mergeWithDefaults(parsed.state || parsed, createDefaultState()),
      activeSection: parsed.activeSection || 'global',
    };
  } catch {
    return { state: createDefaultState(), activeSection: 'global' };
  }
}

function mergeWithDefaults(source, fallback) {
  const base = createDefaultState();
  const merged = structuredClone(base);

  merged.enabled = Boolean(source?.enabled ?? fallback.enabled);
  merged.default_theme = source?.default_theme || fallback.default_theme;
  merged.default_preset = source?.default_preset || fallback.default_preset;
  merged.output_format = source?.output_format || fallback.output_format;
  merged.preview_theme = source?.preview_theme || fallback.preview_theme;

  for (const field of globalFields) {
    merged.global[field.key] = Number(source?.global?.[field.key] ?? fallback.global[field.key]);
  }
  merged.global.tint_color = normalizeTint(source?.global?.tint_color || fallback.global.tint_color);

  for (const themeName of themeOptions) {
    for (const field of themeFields) {
      merged.themes[themeName][field.key] = Number(source?.themes?.[themeName]?.[field.key] ?? fallback.themes[themeName][field.key]);
    }
  }

  for (const field of decorationFields) {
    merged.decoration[field.key] = Number(source?.decoration?.[field.key] ?? fallback.decoration[field.key]);
  }

  merged.layers.enabled = Boolean(source?.layers?.enabled ?? fallback.layers.enabled);
  merged.layers.namespaces = String(source?.layers?.namespaces ?? fallback.layers.namespaces);
  merged.layers.exclude_namespaces = String(source?.layers?.exclude_namespaces ?? fallback.layers.exclude_namespaces);
  merged.layers.preset = String(source?.layers?.preset ?? fallback.layers.preset);
  merged.layers.namespace_presets = String(source?.layers?.namespace_presets ?? fallback.layers.namespace_presets);
  merged.layers.namespace_mask_thresholds = String(source?.layers?.namespace_mask_thresholds ?? fallback.layers.namespace_mask_thresholds);

  merged.window_rules = Array.isArray(source?.window_rules)
    ? source.window_rules.map((r, i) => ({
        enabled: Boolean(r.enabled ?? true),
        match: String(r.match || ''),
        action: String(r.action || ''),
        description: String(r.description || defaultWindowRules[i]?.description || ''),
      }))
    : fallback.window_rules.map((r) => ({ ...r }));

  return merged;
}

function normalizeTint(value) {
  if (!value) return createDefaultState().global.tint_color;
  if (typeof value === 'string') {
    const hex = value.replace(/^0x/i, '').replace(/^#/, '').padEnd(8, 'f').slice(0, 8);
    return { rgb: `#${hex.slice(0, 6)}`, alpha: Number.parseInt(hex.slice(6, 8), 16) };
  }
  return {
    rgb: String(value.rgb || '#8899aa'),
    alpha: Number.isFinite(Number(value.alpha)) ? Number(value.alpha) : 34,
  };
}

function persist() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ state, activeSection }));
  } catch {
    // Some browsers restrict storage for file:// origins.
  }
}

function setNested(path, value) {
  const parts = path.split('.');
  let cursor = state;
  while (parts.length > 1) {
    cursor = cursor[parts.shift()];
  }
  cursor[parts[0]] = value;
  persist();
  render();
}

function resetState() {
  state = createDefaultState();
  activeSection = 'global';
  persist();
  render();
}

function exportText() {
  return state.output_format === 'lua' ? formatLua(state) : formatConf(state);
}

function liveConfigText() {
  return formatConf(state);
}

const API_TIMEOUT_MS = 15000;

function validateConfig() {
  const errors = [];
  const text = liveConfigText();

  if (typeof text !== 'string' || text.trim().length === 0) {
    errors.push('Generated config is empty.');
    return { valid: false, errors };
  }

  if (text.length > 1024 * 1024) {
    errors.push('Generated config is unexpectedly large (>1 MB).');
  }

  if (state.output_format === 'conf') {
    const lines = text.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('= ') || line.startsWith('=')) {
        errors.push(`Line ${i + 1}: missing key before '='`);
      }
    }
  }

  return { valid: errors.length === 0, errors };
}

function checkSyntax() {
  const text = liveConfigText();
  const issues = [];

  if (typeof text !== 'string' || text.trim().length === 0) {
    issues.push('Config is empty.');
  } else {
    const lines = text.split('\n');
    if (state.output_format === 'conf') {
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line || line.startsWith('#')) continue;
        if (line.startsWith('=') || !line.includes('=')) {
          issues.push(`Line ${i + 1}: expected "key = value" form`);
        }
      }
    } else if (state.output_format === 'lua') {
      let openBraces = 0;
      let openParens = 0;
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        for (const ch of line) {
          if (ch === '{') openBraces++;
          if (ch === '}') openBraces--;
          if (ch === '(') openParens++;
          if (ch === ')') openParens--;
        }
        if (openBraces < 0 || openParens < 0) {
          issues.push(`Line ${i + 1}: unexpected closing bracket`);
          break;
        }
      }
      if (openBraces !== 0) issues.push('Unbalanced braces in Lua output.');
      if (openParens !== 0) issues.push('Unbalanced parentheses in Lua output.');
    }
  }

  if (issues.length === 0) {
    syntaxStatus = { ok: true, message: 'Syntax looks good' };
    toast('Syntax check passed', 'success');
  } else {
    syntaxStatus = { ok: false, message: issues.join('; ') };
    showError('Syntax check failed', issues.join('; '));
  }
  render();
}

async function sendConfig(kind) {
  const validation = validateConfig();
  if (!validation.valid) {
    throw new Error(`Config validation failed:\n${validation.errors.join('\n')}`);
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), API_TIMEOUT_MS);

  let response;
  try {
    response = await fetch(`/api/${kind}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ config: liveConfigText() }),
      signal: controller.signal,
    });
  } catch (networkError) {
    clearTimeout(timeoutId);
    if (networkError.name === 'AbortError') {
      throw new Error(`Request to /api/${kind} timed out after ${API_TIMEOUT_MS / 1000}s`);
    }
    throw new Error(`Network error: ${networkError.message || 'Could not reach server'}`);
  }
  clearTimeout(timeoutId);

  const contentType = response.headers.get('content-type') || '';
  let payload = {};
  if (contentType.includes('application/json')) {
    payload = await response.json().catch(() => ({}));
  } else {
    const text = await response.text().catch(() => '');
    payload = { raw: text };
  }

  if (!response.ok || payload.ok === false) {
    throw new Error(payload.error || `Server returned ${response.status} ${response.statusText} for /api/${kind}`);
  }
  return payload;
}

async function copyExport() {
  try {
    await navigator.clipboard.writeText(exportText());
    toast('Copied config to clipboard.', 'success');
  } catch {
    showError('Clipboard access was blocked');
  }
}

function downloadExport() {
  const output = exportText();
  const blob = new Blob([output], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = state.output_format === 'lua' ? 'hyprglass.lua' : 'hyprglass.conf';
  link.click();
  URL.revokeObjectURL(url);
}

function toast(message, type = 'info') {
  const node = document.getElementById('toast');
  if (!node) return;
  node.textContent = message;
  node.dataset.type = type;
  node.classList.add('show');
  clearTimeout(toast.timer);
  const duration = type === 'error' ? 5000 : 2600;
  toast.timer = setTimeout(() => node.classList.remove('show'), duration);
}

function showError(message, detail = '') {
  const summary = detail ? `${message}: ${detail}` : message;
  toast(summary, 'error');
  // Also log to console for debugging.
  console.error(`Hyprglass Studio: ${summary}`);
}

function confirmDialog(message, onConfirm) {
  if (pendingConfirm) return;
  pendingConfirm = { message, onConfirm };
  render();
}

function closeConfirm(confirmed) {
  if (!pendingConfirm) return;
  const { onConfirm } = pendingConfirm;
  pendingConfirm = null;
  render();
  if (confirmed) onConfirm();
}

function setApplying(value) {
  isApplying = value;
  render();
}

function wireEvents() {
  app.addEventListener('input', (event) => {
    const target = event.target;
    const path = target.dataset.path;
    if (!path) return;

    if (target.tagName === 'TEXTAREA') return;

    if (target.type === 'checkbox') {
      setNested(path, target.checked);
      return;
    }

    if (target.dataset.kind === 'int') {
      if (target.value === '') return;
      const parsed = Number.parseInt(target.value, 10);
      if (Number.isFinite(parsed)) setNested(path, parsed);
      return;
    }

    if (target.dataset.kind === 'float') {
      if (target.value === '') return;
      const parsed = Number.parseFloat(target.value);
      if (Number.isFinite(parsed)) setNested(path, parsed);
      return;
    }

    if (target.dataset.kind === 'tint-rgb') {
      setNested(path, { ...state.global.tint_color, rgb: target.value });
      return;
    }

    if (target.dataset.kind === 'tint-alpha') {
      setNested(path, { ...state.global.tint_color, alpha: Number.parseInt(target.value, 10) });
      return;
    }

    setNested(path, target.value);
  });

  app.addEventListener('change', (event) => {
    const target = event.target;
    const path = target.dataset.path;
    if (!path) return;
    if (target.tagName === 'SELECT' || target.tagName === 'TEXTAREA') {
      setNested(path, target.value);
    }
  });

  app.addEventListener('click', async (event) => {
    const target = event.target;
    const action = target.dataset.action;
    if (!action) return;

    if (action === 'confirm-yes') return closeConfirm(true);
    if (action === 'confirm-no') return closeConfirm(false);

    if (action === 'section') {
      activeSection = target.dataset.section;
      persist();
      render();
      return;
    }

    if (action === 'reset') {
      confirmDialog('Reset all settings to their default values? This cannot be undone.', () => {
        resetState();
        toast('Settings reset to defaults.', 'success');
      });
      return;
    }

    if (action === 'preview') {
      try {
        await sendConfig('preview');
        toast('Preview opened in kitty.', 'success');
      } catch (error) {
        showError('Preview failed', error.message);
      }
      return;
    }

    if (action === 'apply') {
      confirmDialog('Apply the current config to Hyprland?', async () => {
        setApplying(true);
        try {
          await sendConfig('apply');
          toast('Applied to Hyprland.', 'success');
        } catch (error) {
          showError('Apply failed', error.message);
        } finally {
          setApplying(false);
        }
      });
      return;
    }

    if (action === 'check-syntax') return checkSyntax();
    if (action === 'copy') return copyExport();
    if (action === 'download') return downloadExport();
    if (action === 'set-format') return setNested('output_format', target.dataset.format);
    if (action === 'set-theme') return setNested('preview_theme', target.dataset.theme);

    if (action === 'sample-layers') {
      setNested('layers.namespaces', 'waybar, swaync, notifications, quickshell:overview, quickshell:bezel, rofi');
      setNested('layers.exclude_namespaces', '');
      setNested('layers.preset', 'subtle');
      setNested('layers.namespace_presets', 'waybar:subtle, quickshell:bezel:ui');
      setNested('layers.namespace_mask_thresholds', 'waybar=0.05, quickshell:overview=0.3, quickshell:bezel=0.3, rofi=0.05');
      return;
    }

    if (action === 'add-window-rule') {
      const rules = [...(state.window_rules || [])];
      rules.push({ enabled: false, match: '', action: '', description: '' });
      setNested('window_rules', rules);
      return;
    }

    if (action === 'remove-window-rule') {
      const idx = Number(target.dataset.index);
      if (Number.isFinite(idx)) {
        const rules = [...(state.window_rules || [])];
        rules.splice(idx, 1);
        setNested('window_rules', rules);
      }
      return;
    }
  });

  document.addEventListener('keydown', (event) => {
    if (event.ctrlKey && event.key.toLowerCase() === 's') {
      event.preventDefault();
      app.querySelector('[data-action="apply"]')?.click();
      return;
    }
    if (event.ctrlKey && event.key.toLowerCase() === 'p') {
      event.preventDefault();
      app.querySelector('[data-action="preview"]')?.click();
      return;
    }
    if (event.key === 'Escape' && pendingConfirm) {
      closeConfirm(false);
    }
  });
}

function render() {
  const summary = summarizeState(state);
  const preview = exportText();
  app.innerHTML = `
    <div class="shell ${isApplying ? 'applying' : ''}">
      <aside class="sidebar">
        <div class="brand">
          <h1>Hyprglass Studio</h1>
          <p>Standalone editor for Hyprglass config, with reversible local export.</p>
        </div>
        <nav class="nav">
          ${navButton('global', 'Global settings')}
          ${navButton('theme', 'Theme settings')}
          ${navButton('layers', 'Layer surfaces')}
          ${navButton('decoration', 'Decoration')}
          ${navButton('windowrules', 'Window rules')}
          ${navButton('export', 'Export')}
        </nav>
        <div class="meta">
          ${renderStatusPanel(summary)}
          <button class="action" data-action="reset" title="Reset all settings to defaults">Reset to defaults</button>
        </div>
      </aside>

      <main class="content">
        <div class="header">
          <div>
            <h2>${sectionTitle(activeSection)}</h2>
            <p class="muted">${sectionDescription(activeSection)}</p>
          </div>
          <div class="actions">
            ${activeSection === 'layers' ? '<button class="action" data-action="sample-layers">Use sample layers</button>' : ''}
            <button class="action" data-action="check-syntax" title="Validate generated config syntax">Check syntax</button>
            <button class="action" data-action="preview" title="Preview in kitty (Ctrl+P)">Preview</button>
            <button class="action primary" data-action="apply" title="Apply to Hyprland (Ctrl+S)" ${isApplying ? 'disabled' : ''}>Apply</button>
            <button class="action" data-action="copy">Copy config</button>
            <button class="action primary" data-action="download">Download</button>
          </div>
        </div>
        ${renderSection()}
      </main>

      <aside class="preview">
        <div class="preview-head">
          <div class="inline-list">
            ${formatToggle('conf', 'CONF')}
            ${formatToggle('lua', 'Lua')}
          </div>
          <div class="inline-list">
            ${themeToggle('dark')}
            ${themeToggle('light')}
          </div>
          <div class="badge-row">
            <span class="badge accent">default theme: ${state.default_theme}</span>
            <span class="badge accent">default preset: ${state.default_preset}</span>
            <span class="badge">${parseCommaList(state.layers.namespaces).length} whitelisted</span>
          </div>
          <p class="help">The export panel follows the plugin's resolution order. Change the fields on the left and the config text updates immediately.</p>
        </div>
        <div class="panel">
          <h3>Export profile</h3>
          <div class="split">
            <label class="field-row">
              <span>Default theme</span>
              <select data-path="default_theme">
                ${themeOptions.map((theme) => `<option value="${theme}" ${state.default_theme === theme ? 'selected' : ''}>${theme}</option>`).join('')}
              </select>
            </label>
            <label class="field-row">
              <span>Default preset</span>
              <select data-path="default_preset">
                ${presetOptions.map((preset) => `<option value="${preset}" ${state.default_preset === preset ? 'selected' : ''}>${preset}</option>`).join('')}
              </select>
            </label>
          </div>
        </div>
        <div class="preview-box">
          <pre>${escapeHtml(preview)}</pre>
        </div>
      </aside>
    </div>
    ${renderConfirmDialog()}
    ${renderLoadingOverlay()}
    <div id="toast" class="toast" aria-live="polite" role="status"></div>
  `;
}

function renderStatusPanel(summary) {
  return `
    <div class="panel status-panel">
      <h3>Status</h3>
      <div class="status-grid">
        <div class="status-item">
          <span class="status-label">Plugin</span>
          <span class="badge ${summary.enabled ? 'good' : 'warn'}">${summary.enabled ? 'Enabled' : 'Disabled'}</span>
        </div>
        <div class="status-item">
          <span class="status-label">Preview theme</span>
          <span class="badge good">${summary.activeTheme}</span>
        </div>
        <div class="status-item">
          <span class="status-label">Layers</span>
          <span class="badge ${summary.layersEnabled ? 'good' : 'warn'}">${summary.layersEnabled ? 'On' : 'Off'}</span>
        </div>
        <div class="status-item">
          <span class="status-label">Globals</span>
          <span class="badge">${summary.globals}</span>
        </div>
        <div class="status-item">
          <span class="status-label">Theme values</span>
          <span class="badge">${summary.themeCount}</span>
        </div>
        <div class="status-item">
          <span class="status-label">Active rules</span>
          <span class="badge">${summary.activeRules}</span>
        </div>
        <div class="status-item">
          <span class="status-label">Syntax check</span>
          <span class="badge ${syntaxStatus.ok === true ? 'good' : syntaxStatus.ok === false ? 'warn' : ''}" title="${escapeHtml(syntaxStatus.message || 'Run Check syntax to validate output')}">${syntaxStatus.ok === true ? 'OK' : syntaxStatus.ok === false ? 'Issues' : 'Not checked'}</span>
        </div>
      </div>
      <p class="help">Resolved config is previewed in the right panel and saved in your browser's local storage.</p>
    </div>
  `;
}

function renderConfirmDialog() {
  if (!pendingConfirm) return '';
  return `
    <div class="modal-backdrop" role="dialog" aria-modal="true" aria-labelledby="confirm-title">
      <div class="modal">
        <h3 id="confirm-title">Confirm</h3>
        <p>${escapeHtml(pendingConfirm.message)}</p>
        <div class="modal-actions">
          <button class="action" data-action="confirm-no">Cancel</button>
          <button class="action primary" data-action="confirm-yes">Confirm</button>
        </div>
      </div>
    </div>
  `;
}

function renderLoadingOverlay() {
  if (!isApplying) return '';
  return `
    <div class="loading-overlay" role="status" aria-live="polite">
      <div class="spinner"></div>
      <span>Applying config to Hyprland…</span>
    </div>
  `;
}

function navButton(section, label) {
  return `<button class="${activeSection === section ? 'active' : ''}" data-action="section" data-section="${section}">${label}</button>`;
}

function formatToggle(format, label) {
  const active = state.output_format === format;
  return `<button class="chip-button ${active ? 'active' : ''}" data-action="set-format" data-format="${format}">${label}</button>`;
}

function themeToggle(theme) {
  const active = state.preview_theme === theme;
  return `<button class="chip-button ${active ? 'active' : ''}" data-action="set-theme" data-theme="${theme}">${theme}</button>`;
}

function sectionTitle(section) {
  switch (section) {
    case 'theme':
      return 'Per-theme controls';
    case 'layers':
      return 'Layer surfaces';
    case 'decoration':
      return 'Decoration settings';
    case 'windowrules':
      return 'Window rules';
    case 'export':
      return 'Export and preview';
    default:
      return 'Global controls';
  }
}

function sectionDescription(section) {
  switch (section) {
    case 'theme':
      return 'Dark and light overrides for the theme-dependent values.';
    case 'layers':
      return 'Configure bars, docks, widgets, and excluded namespaces.';
    case 'decoration':
      return 'Opacity settings for focused, unfocused, and fullscreen windows.';
    case 'windowrules':
      return 'Per-window glass rules and compatibility settings.';
    case 'export':
      return 'Choose conf or Lua output, then copy or download the result.';
    default:
      return 'Global values that feed the plugin before theme-specific overrides.';
  }
}

function renderSection() {
  if (activeSection === 'theme') {
    return `
      <div class="grid-two">
        ${themePanel('dark')}
        ${themePanel('light')}
      </div>
    `;
  }

  if (activeSection === 'layers') {
    return `
      <div class="panel">
        <div class="stack">
          ${toggleField('layers.enabled', 'Enable layer surfaces', layerFields[0].description)}
          ${textField('layers.namespaces', 'Namespace whitelist', layerFields[1].description, 'waybar, swaync, rofi')}
          ${textField('layers.exclude_namespaces', 'Namespace blacklist', layerFields[2].description, 'debug-panel, overlays')}
          ${textField('layers.preset', 'Layer preset', layerFields[3].description, 'subtle')}
          ${textField('layers.namespace_presets', 'Namespace presets', layerFields[4].description, 'waybar:subtle, quickshell:bezel:ui')}
          ${textField('layers.namespace_mask_thresholds', 'Mask thresholds', layerFields[5].description, 'waybar=0.05, quickshell:bezel=0.3')}
        </div>
      </div>
    `;
  }

  if (activeSection === 'decoration') {
    return `
      <div class="panel">
        <h3>Window opacity</h3>
        <p class="subhead">Controls how transparent windows are. Opacity must be below 1.0 for glass to render — at 1.0 the window is fully opaque and the glass effect is hidden behind it.</p>
        <div class="stack">
          ${decorationFields.map((field) => sliderCard({
            ...field,
            path: `decoration.${field.key}`,
            value: state.decoration[field.key],
          })).join('')}
        </div>
      </div>
    `;
  }

  if (activeSection === 'windowrules') {
    return `
      <div class="panel">
        <h3>Window rules</h3>
        <p class="subhead">Configure per-window glass behavior. Rules are applied in order.</p>
        <div class="stack" id="window-rules-list">
          ${(state.window_rules || []).map((rule, index) => windowRuleCard(rule, index)).join('')}
        </div>
        <button class="action" data-action="add-window-rule" style="margin-top:12px">Add rule</button>
      </div>
    `;
  }

  if (activeSection === 'export') {
    return `
      <div class="grid-two">
        <div class="panel">
          <h3>Global summary</h3>
          <p class="subhead">Current runtime state from your controls.</p>
          <div class="badge-row">
            <span class="badge ${state.enabled ? 'good' : 'warn'}">plugin ${state.enabled ? 'enabled' : 'disabled'}</span>
            <span class="badge good">theme: ${state.default_theme}</span>
            <span class="badge accent">preset: ${state.default_preset}</span>
            <span class="badge">${globalFields.length} global vars</span>
            <span class="badge">${themeFields.length * 2} theme vars</span>
          </div>
        </div>
        <div class="panel">
          <h3>Layer summary</h3>
          <p class="subhead">Current layer config state.</p>
          <div class="badge-row">
            <span class="badge ${state.layers.enabled ? 'good' : 'warn'}">${state.layers.enabled ? 'layer glass enabled' : 'layer glass disabled'}</span>
            <span class="badge">${parseCommaList(state.layers.namespaces).length} namespaces</span>
            <span class="badge">${parseCommaList(state.layers.exclude_namespaces).length} excluded</span>
          </div>
        </div>
      </div>
      <div class="grid-two" style="margin-top:16px">
        <div class="panel">
          <h3>Decoration summary</h3>
          <p class="subhead">Opacity settings for different window states.</p>
          <div class="badge-row">
            <span class="badge">active: ${state.decoration.active_opacity}</span>
            <span class="badge">inactive: ${state.decoration.inactive_opacity}</span>
            <span class="badge">fullscreen: ${state.decoration.fullscreen_opacity}</span>
          </div>
        </div>
        <div class="panel">
          <h3>Window rules summary</h3>
          <p class="subhead">Active per-window rules.</p>
          <div class="badge-row">
            <span class="badge">${(state.window_rules || []).filter((r) => r.enabled).length} active rules</span>
            <span class="badge">${(state.window_rules || []).filter((r) => !r.enabled).length} disabled</span>
          </div>
        </div>
      </div>
    `;
  }

  return `
    <div class="section-grid">
      <div class="panel">
        <h3>Defaults</h3>
        <p class="subhead">These apply globally before theme overrides.</p>
        <div class="split">
          ${globalFields.slice(0, 5).map((field) => globalCard(field)).join('')}
          <div class="setting">
            <div class="setting-head">
              <strong>Tint color</strong>
              <span>${serializeTintState(state.global.tint_color)}</span>
            </div>
            <p class="desc">Glass tint RRGGBBAA. Alpha controls tint strength.</p>
            ${tintField()}
          </div>
        </div>
      </div>
      <div class="panel">
        <h3>Additional globals</h3>
        <p class="subhead">The remaining global values.</p>
        <div class="mini-grid">
          ${globalFields.slice(5).map((field) => globalCard(field)).join('')}
        </div>
      </div>
      <div class="panel">
        <h3>Plugin status</h3>
        <p class="subhead">Enable or disable the glass effect globally.</p>
        <div class="setting">
          <div class="setting-head">
            <strong>Enable plugin</strong>
            <span>${state.enabled ? 'on' : 'off'}</span>
          </div>
          <p class="desc">Master switch for the glass effect. When disabled, no windows will have glass.</p>
          <label class="inline-list" style="align-items:center">
            <input type="checkbox" ${state.enabled ? 'checked' : ''} data-path="enabled" />
            <span>Enabled</span>
          </label>
        </div>
      </div>
    </div>
  `;
}

function globalCard(field) {
  return sliderCard({
    ...field,
    path: `global.${field.key}`,
    value: state.global[field.key],
  });
}

function themePanel(theme) {
  const title = theme === 'dark' ? 'Dark theme' : 'Light theme';
  return `
    <div class="panel">
      <h3>${title}</h3>
      <p class="subhead">${theme === 'dark' ? 'Dark default values and overrides.' : 'Light default values and overrides.'}</p>
      <div class="stack">
        ${themeFields.map((field) => sliderCard({
          ...field,
          path: `themes.${theme}.${field.key}`,
          value: state.themes[theme][field.key],
        })).join('')}
      </div>
    </div>
  `;
}

function sliderCard(field) {
  const valueText = Number.isInteger(field.step) && field.step === 1
    ? String(Math.round(Number(field.value)))
    : Number(field.value).toFixed(field.key === 'edge_thickness' ? 3 : 2).replace(/0+$/, '').replace(/\.$/, '');
  return `
    <div class="setting">
      <div class="setting-head">
        <strong>${field.label}</strong>
        <span>${valueText}</span>
      </div>
      <p class="desc">${field.description}</p>
      <div class="slider-row">
        <input
          type="range"
          min="${field.min}"
          max="${field.max}"
          step="${field.step}"
          value="${field.value}"
          data-path="${field.path}"
          data-kind="${Number.isInteger(field.step) && field.step === 1 ? 'int' : 'float'}"
        />
        <input
          type="number"
          min="${field.min}"
          max="${field.max}"
          step="${field.step}"
          value="${field.value}"
          data-path="${field.path}"
          data-kind="${Number.isInteger(field.step) && field.step === 1 ? 'int' : 'float'}"
        />
      </div>
    </div>
  `;
}

function tintField() {
  return `
    <div class="color-row">
      <input type="color" value="${state.global.tint_color.rgb}" data-path="global.tint_color" data-kind="tint-rgb" />
      <input type="text" value="${serializeTintState(state.global.tint_color)}" readonly />
      <input type="number" min="0" max="255" step="1" value="${state.global.tint_color.alpha}" data-path="global.tint_color" data-kind="tint-alpha" />
    </div>
  `;
}

function toggleField(path, label, description) {
  const checked = getByPath(path);
  return `
    <div class="setting">
      <div class="setting-head">
        <strong>${label}</strong>
        <span>${checked ? 'on' : 'off'}</span>
      </div>
      <p class="desc">${description}</p>
      <label class="inline-list" style="align-items:center">
        <input type="checkbox" ${checked ? 'checked' : ''} data-path="${path}" />
        <span>Enabled</span>
      </label>
    </div>
  `;
}

function textField(path, label, description, placeholder = '') {
  return `
    <label class="field-row">
      <span>${label}</span>
      <textarea data-path="${path}" placeholder="${placeholder}">${escapeHtml(getByPath(path) || '')}</textarea>
      <span class="help">${description}</span>
    </label>
  `;
}

function getByPath(path) {
  return path.split('.').reduce((cursor, part) => cursor?.[part], state);
}

function windowRuleCard(rule, index) {
  return `
    <div class="setting" style="border-left: 3px solid ${rule.enabled ? 'var(--accent)' : 'var(--line)'}">
      <div class="setting-head">
        <strong>${rule.description || `Rule ${index + 1}`}</strong>
        <span>${rule.enabled ? 'active' : 'disabled'}</span>
      </div>
      <div class="split">
        <label class="field-row">
          <span>Match condition</span>
          <input type="text" value="${escapeHtml(rule.match)}" data-path="window_rules.${index}.match" placeholder="class ^(waterfox)$" />
        </label>
        <label class="field-row">
          <span>Action</span>
          <input type="text" value="${escapeHtml(rule.action)}" data-path="window_rules.${index}.action" placeholder="tag +hyprglass_enabled" />
        </label>
      </div>
      <div class="inline-list" style="align-items:center; gap:12px">
        <label class="inline-list" style="align-items:center">
          <input type="checkbox" ${rule.enabled ? 'checked' : ''} data-path="window_rules.${index}.enabled" />
          <span>Enabled</span>
        </label>
        <button class="action danger" data-action="remove-window-rule" data-index="${index}" style="padding:6px 10px; font-size:0.85rem">Remove</button>
      </div>
    </div>
  `;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}
