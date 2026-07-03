const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mj-charactercreator';

const categoryOrder = [
  ['component', 0, 'Face'],
  ['component', 2, 'Hair'],
  ['component', 1, 'Mask'],
  ['component', 11, 'Tops'],
  ['component', 8, 'Undershirt'],
  ['component', 3, 'Arms'],
  ['component', 4, 'Pants'],
  ['component', 6, 'Shoes'],
  ['component', 7, 'Accessories'],
  ['component', 5, 'Bags'],
  ['component', 9, 'Armor'],
  ['component', 10, 'Decals'],
  ['prop', 0, 'Hats'],
  ['prop', 1, 'Glasses'],
  ['prop', 2, 'Ears'],
  ['prop', 6, 'Watches'],
  ['prop', 7, 'Bracelets']
];

const state = {
  open: false,
  loading: false,
  gender: 'male',
  clothing: null,
  appearance: null,
  cameraViews: [],
  activeCategory: { type: 'component', id: 11, name: 'Tops' },
  selections: {},
  activeView: 'full',
  applyTimer: null
};

const el = {
  app: document.getElementById('app'),
  loadingOverlay: document.getElementById('loadingOverlay'),
  tabs: document.getElementById('categoryTabs'),
  selectedTitle: document.getElementById('selectedTitle'),
  collectionSelect: document.getElementById('collectionSelect'),
  drawableRange: document.getElementById('drawableRange'),
  drawableNumber: document.getElementById('drawableNumber'),
  textureRange: document.getElementById('textureRange'),
  textureNumber: document.getElementById('textureNumber'),
  searchInput: document.getElementById('searchInput'),
  genderMale: document.getElementById('genderMale'),
  genderFemale: document.getElementById('genderFemale'),
  cameraButtons: document.getElementById('cameraButtons'),
  activeViewLabel: document.getElementById('activeViewLabel'),
  scanLabel: document.getElementById('scanLabel'),
  toast: document.getElementById('statusToast')
};

function keyFor(category) {
  return `${category.type}:${category.id}`;
}

function post(endpoint, payload = {}) {
  return fetch(`https://${resourceName}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
  }).then((response) => response.json().catch(() => ({ ok: false, error: 'Invalid response' })));
}

function showToast(message) {
  if (!message) {
    el.toast.classList.add('hidden');
    return;
  }

  el.toast.textContent = message;
  el.toast.classList.remove('hidden');
  window.setTimeout(() => el.toast.classList.add('hidden'), 2600);
}

function setLoading(enabled) {
  state.loading = enabled;
  el.loadingOverlay.classList.toggle('hidden', !enabled);
  el.scanLabel.textContent = enabled ? 'Scanning' : 'Ready';
}

function setOpen(enabled) {
  state.open = enabled;
  el.app.classList.toggle('hidden', !enabled);
  el.app.setAttribute('aria-hidden', enabled ? 'false' : 'true');
}

function getCategoryData(category = state.activeCategory) {
  if (!state.clothing) return null;
  const bucket = category.type === 'prop' ? state.clothing.props : state.clothing.components;
  return bucket ? bucket[String(category.id)] : null;
}

function getSelection(category = state.activeCategory) {
  const key = keyFor(category);

  if (!state.selections[key]) {
    const saved = category.type === 'prop'
      ? state.appearance?.props?.[String(category.id)]
      : state.appearance?.components?.[String(category.id)];

    state.selections[key] = {
      collection: saved?.collection || '',
      drawable: Number.isFinite(Number(saved?.drawable)) ? Number(saved.drawable) : 0,
      texture: Number.isFinite(Number(saved?.texture)) ? Number(saved.texture) : 0
    };
  }

  return state.selections[key];
}

function getSelectedCollection(category = state.activeCategory) {
  const data = getCategoryData(category);
  const selection = getSelection(category);

  if (!data || !Array.isArray(data.collections) || data.collections.length === 0) {
    return null;
  }

  return data.collections.find((item) => item.collection === selection.collection) || data.collections[0];
}

function getDrawableInfo(collection, drawable) {
  if (!collection || !Array.isArray(collection.drawables)) return null;
  return collection.drawables.find((item) => Number(item.drawable) === Number(drawable)) || collection.drawables[0] || null;
}

function firstDrawable(collection) {
  if (!collection || !Array.isArray(collection.drawables) || collection.drawables.length === 0) return 0;
  return Number(collection.drawables[0].drawable) || 0;
}

function closestDrawable(collection, drawable) {
  if (!collection || !Array.isArray(collection.drawables) || collection.drawables.length === 0) return 0;
  const target = Number(drawable) || 0;
  return collection.drawables.reduce((best, item) => {
    const value = Number(item.drawable) || 0;
    return Math.abs(value - target) < Math.abs(best - target) ? value : best;
  }, Number(collection.drawables[0].drawable) || 0);
}

function maxDrawable(collection) {
  if (!collection || !Array.isArray(collection.drawables) || collection.drawables.length === 0) return 0;
  return collection.drawables.reduce((max, item) => Math.max(max, Number(item.drawable) || 0), 0);
}

function renderTabs() {
  const query = el.searchInput.value.trim().toLowerCase();
  el.tabs.innerHTML = '';

  categoryOrder
    .filter(([, , name]) => !query || name.toLowerCase().includes(query))
    .forEach(([type, id, name]) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = name;
      button.classList.toggle('active', state.activeCategory.type === type && state.activeCategory.id === id);
      button.addEventListener('click', () => {
        state.activeCategory = { type, id, name };
        renderTabs();
        renderControls();
      });
      el.tabs.appendChild(button);
    });
}

function renderGender() {
  el.genderMale.classList.toggle('active', state.gender === 'male');
  el.genderFemale.classList.toggle('active', state.gender === 'female');
}

function renderCameraButtons() {
  el.cameraButtons.innerHTML = '';

  state.cameraViews.forEach((view) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = view.label;
    button.classList.toggle('active', state.activeView === view.name);
    button.addEventListener('click', () => {
      state.activeView = view.name;
      el.activeViewLabel.textContent = view.label;
      renderCameraButtons();
      post('setCameraView', { view: view.name }).then((result) => {
        if (!result.ok) showToast(result.error);
      });
    });
    el.cameraButtons.appendChild(button);
  });
}

function renderControls() {
  const category = state.activeCategory;
  const data = getCategoryData(category);
  const selection = getSelection(category);
  const collections = Array.isArray(data?.collections) ? data.collections : [];

  el.selectedTitle.textContent = category.name;
  el.collectionSelect.innerHTML = '';

  collections.forEach((collection) => {
    const option = document.createElement('option');
    option.value = collection.collection;
    option.textContent = collection.label || collection.collection || 'Base Game';
    el.collectionSelect.appendChild(option);
  });

  el.collectionSelect.disabled = collections.length === 0;

  if (collections.length > 0 && !collections.some((item) => item.collection === selection.collection)) {
    selection.collection = collections[0].collection;
  }

  el.collectionSelect.value = selection.collection;

  const collection = getSelectedCollection(category);
  const drawableInfo = getDrawableInfo(collection, selection.drawable);

  if (drawableInfo) {
    selection.drawable = Number(drawableInfo.drawable) || 0;
  }

  const drawableMax = maxDrawable(collection);
  const textureMax = Math.max(0, (Number(drawableInfo?.textures) || 1) - 1);

  el.drawableRange.max = String(drawableMax);
  el.drawableRange.value = String(selection.drawable);
  el.drawableNumber.max = String(drawableMax);
  el.drawableNumber.value = String(selection.drawable);
  el.textureRange.max = String(textureMax);
  el.textureNumber.max = String(textureMax);

  if (selection.texture > textureMax) {
    selection.texture = textureMax;
  }

  el.textureRange.value = String(selection.texture);
  el.textureNumber.value = String(selection.texture);

  const disabled = collections.length === 0;
  [el.drawableRange, el.drawableNumber, el.textureRange, el.textureNumber].forEach((input) => {
    input.disabled = disabled;
  });
}

function applyCurrentSelection(immediate = false) {
  window.clearTimeout(state.applyTimer);

  const run = () => {
    const category = state.activeCategory;
    const selection = getSelection(category);

    if (category.type === 'prop') {
      post('setProp', {
        prop: category.id,
        collection: selection.collection,
        drawable: selection.drawable,
        texture: selection.texture
      }).then(handleApplyResult);
      return;
    }

    post('setComponent', {
      component: category.id,
      collection: selection.collection,
      drawable: selection.drawable,
      texture: selection.texture,
      palette: 0
    }).then(handleApplyResult);
  };

  if (immediate) {
    run();
  } else {
    state.applyTimer = window.setTimeout(run, 120);
  }
}

function handleApplyResult(result) {
  if (!result.ok) {
    showToast(result.error || 'Unable to preview item');
    return;
  }

  if (result.appearance) {
    state.appearance = result.appearance;
  }
}

function setDrawable(value) {
  const selection = getSelection();
  const collection = getSelectedCollection();
  const drawable = Math.max(0, Math.min(maxDrawable(collection), Number(value) || 0));
  selection.drawable = closestDrawable(collection, drawable);
  selection.texture = 0;
  renderControls();
  applyCurrentSelection();
}

function setTexture(value) {
  const selection = getSelection();
  const drawableInfo = getDrawableInfo(getSelectedCollection(), selection.drawable);
  const max = Math.max(0, (Number(drawableInfo?.textures) || 1) - 1);
  selection.texture = Math.max(0, Math.min(max, Number(value) || 0));
  renderControls();
  applyCurrentSelection();
}

function stepDrawable(direction) {
  const collection = getSelectedCollection();
  const selection = getSelection();
  const drawables = collection?.drawables || [];

  if (drawables.length === 0) return;

  const currentIndex = Math.max(0, drawables.findIndex((item) => Number(item.drawable) === Number(selection.drawable)));
  const nextIndex = (currentIndex + direction + drawables.length) % drawables.length;
  selection.drawable = Number(drawables[nextIndex].drawable) || 0;
  selection.texture = 0;
  renderControls();
  applyCurrentSelection(true);
}

function randomizeCategory() {
  const collection = getSelectedCollection();
  const selection = getSelection();
  const drawables = collection?.drawables || [];

  if (drawables.length === 0) return;

  const drawable = drawables[Math.floor(Math.random() * drawables.length)];
  selection.drawable = Number(drawable.drawable) || 0;
  selection.texture = Math.floor(Math.random() * Math.max(1, Number(drawable.textures) || 1));
  renderControls();
  applyCurrentSelection(true);
}

function resetCategory() {
  const category = state.activeCategory;
  const selection = getSelection(category);
  const data = getCategoryData(category);
  const base = data?.collections?.find((item) => item.collection === '') || data?.collections?.[0];

  selection.collection = base?.collection || '';
  selection.drawable = base?.drawables?.[0]?.drawable || 0;
  selection.texture = 0;
  renderControls();

  if (category.type === 'prop') {
    post('clearProp', { prop: category.id }).then(handleApplyResult);
    return;
  }

  applyCurrentSelection(true);
}

function refreshFromPayload(payload) {
  if (payload.gender) state.gender = payload.gender;
  if (payload.appearance) state.appearance = payload.appearance;
  if (payload.clothing) state.clothing = payload.clothing;
  if (payload.cameraViews) state.cameraViews = payload.cameraViews;

  renderGender();
  renderTabs();
  renderControls();
  renderCameraButtons();
}

window.addEventListener('message', (event) => {
  const data = event.data || {};

  if (data.action === 'open') {
    setOpen(true);
    setLoading(data.loading === true);
    refreshFromPayload(data);
    return;
  }

  if (data.action === 'close') {
    setOpen(false);
    setLoading(false);
    return;
  }

  if (data.action === 'loading') {
    setLoading(data.loading === true);
    return;
  }

  if (data.action === 'creatorData') {
    setLoading(data.loading === true);
    refreshFromPayload(data);
    if (data.error) showToast(data.error);
  }
});

el.collectionSelect.addEventListener('change', () => {
  const selection = getSelection();
  const collection = getSelectedCollection();
  selection.collection = el.collectionSelect.value;
  const nextCollection = getSelectedCollection();
  selection.drawable = firstDrawable(nextCollection || collection);
  selection.texture = 0;
  renderControls();
  applyCurrentSelection(true);
});

el.drawableRange.addEventListener('input', (event) => setDrawable(event.target.value));
el.drawableNumber.addEventListener('change', (event) => setDrawable(event.target.value));
el.textureRange.addEventListener('input', (event) => setTexture(event.target.value));
el.textureNumber.addEventListener('change', (event) => setTexture(event.target.value));
el.searchInput.addEventListener('input', renderTabs);

document.getElementById('prevDrawable').addEventListener('click', () => stepDrawable(-1));
document.getElementById('nextDrawable').addEventListener('click', () => stepDrawable(1));
document.getElementById('randomizeCategory').addEventListener('click', randomizeCategory);
document.getElementById('resetCategory').addEventListener('click', resetCategory);

document.getElementById('saveButton').addEventListener('click', () => {
  post('saveCharacter').then((result) => {
    if (!result.ok) {
      showToast(result.error);
      return;
    }

    if (result.appearance) state.appearance = result.appearance;
    showToast('Appearance saved');
  });
});

document.getElementById('closeButton').addEventListener('click', () => post('closeCreator'));
document.getElementById('rotateLeft').addEventListener('click', () => post('rotatePed', { direction: 'left' }));
document.getElementById('rotateRight').addEventListener('click', () => post('rotatePed', { direction: 'right' }));
document.getElementById('zoomIn').addEventListener('click', () => post('zoomCamera', { delta: -0.2 }));
document.getElementById('zoomOut').addEventListener('click', () => post('zoomCamera', { delta: 0.2 }));

[el.genderMale, el.genderFemale].forEach((button) => {
  button.addEventListener('click', () => {
    const gender = button.dataset.gender;
    if (gender === state.gender) return;

    setLoading(true);
    post('setGender', { gender }).then((result) => {
      setLoading(false);

      if (!result.ok) {
        showToast(result.error);
        return;
      }

      state.selections = {};
      refreshFromPayload(result);
    });
  });
});

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && state.open) {
    post('closeCreator');
  }
});

renderTabs();
renderControls();
