// Authentic PZ Build 42 UI Simulation Engine
document.addEventListener('DOMContentLoaded', () => {

  const state = {
    batteryPercent: 78,
    maxCapacity: 4000,
    solarRad: 85,
    baseLoad: 1200,
    genThreshold: 20,
    panelWattsPerUnit: 180,
    panelCount: 12,
  };

  // Sliders
  const sliderSolar = document.getElementById('slider-solar-rad');
  const sliderCap = document.getElementById('slider-batt-cap');
  const sliderLoad = document.getElementById('slider-base-load');
  const sliderGen = document.getElementById('slider-gen-thresh');

  // Slider Value Labels
  const valSolar = document.getElementById('val-solar-rad');
  const valCap = document.getElementById('val-batt-cap');
  const valLoad = document.getElementById('val-base-load');
  const valGen = document.getElementById('val-gen-thresh');

  // Option Switcher Buttons
  const btnOpt1 = document.getElementById('btn-opt-1');
  const btnOpt2 = document.getElementById('btn-opt-2');
  const btnOpt3 = document.getElementById('btn-opt-3');
  const viewOpt1 = document.getElementById('view-opt-1');
  const viewOpt2 = document.getElementById('view-opt-2');
  const viewOpt3 = document.getElementById('view-opt-3');

  function updateSimulation() {
    state.solarRad = parseInt(sliderSolar.value, 10);
    state.maxCapacity = parseInt(sliderCap.value, 10);
    state.baseLoad = parseInt(sliderLoad.value, 10);
    state.genThreshold = parseInt(sliderGen.value, 10);

    const totalSolarWatts = Math.round((state.panelCount * state.panelWattsPerUnit) * (state.solarRad / 100));
    const netWatts = totalSolarWatts - state.baseLoad;
    const currentAh = Math.round(state.maxCapacity * (state.batteryPercent / 100));

    // Slider text
    valSolar.textContent = `${state.solarRad} %`;
    valCap.textContent = `${state.maxCapacity.toLocaleString('de-DE')} Ah`;
    valLoad.textContent = `${state.baseLoad.toLocaleString('de-DE')} W`;
    valGen.textContent = `${state.genThreshold} %`;

    // Colors & Status based on Battery Percent
    let barColor = 'var(--pz-green)';
    let textColor = '#4ade80';
    if (state.batteryPercent < 25) {
      barColor = 'var(--pz-red)';
      textColor = '#f87171';
    } else if (state.batteryPercent < 55) {
      barColor = 'var(--pz-yellow)';
      textColor = '#facc15';
    }

    let weatherDesc = 'Klarer Himmel';
    if (state.solarRad < 25) weatherDesc = 'Dichte Wolken / Dämmerung';
    else if (state.solarRad < 65) weatherDesc = 'Bewölkt';
    else if (state.solarRad < 10) weatherDesc = 'Nacht';

    // Calculate Time Estimate
    let timeEstText = '';
    let isCharging = netWatts >= 0;
    if (isCharging) {
      const remainingAh = state.maxCapacity - currentAh;
      const hours = netWatts > 0 ? (remainingAh / (netWatts / 12)).toFixed(1) : 0;
      timeEstText = hours > 0 ? `~${hours}h bis 100% Voll` : 'Voll geladen';
    } else {
      const drainWatts = Math.abs(netWatts);
      const hours = (currentAh / (drainWatts / 12)).toFixed(1);
      timeEstText = `~${hours}h bis Leer (0%)`;
    }

    // ==========================================
    // UPDATE OPTION 1: Tactical Box Dashboard
    // ==========================================
    const opt1Pill = document.getElementById('opt1-pill-status');
    const opt1Percent = document.getElementById('opt1-text-percent');
    const opt1BarFill = document.getElementById('opt1-bar-fill');
    const opt1BarLabel = document.getElementById('opt1-bar-label');
    const opt1MaxCap = document.getElementById('opt1-max-cap');
    const opt1CurCap = document.getElementById('opt1-cur-cap');
    const opt1NetFlow = document.getElementById('opt1-net-flow');
    const opt1TimeEst = document.getElementById('opt1-time-est');
    const opt1SolarWatts = document.getElementById('opt1-solar-watts');
    const opt1WeatherDesc = document.getElementById('opt1-weather-desc');
    const opt1BaseLoad = document.getElementById('opt1-base-load');
    const opt1GenThresh = document.getElementById('opt1-gen-thresh');

    if (opt1Percent) {
      opt1Percent.textContent = `${state.batteryPercent} % — ${currentAh.toLocaleString('de-DE')} / ${state.maxCapacity.toLocaleString('de-DE')} Ah`;
      opt1BarFill.style.width = `${state.batteryPercent}%`;
      opt1BarFill.style.backgroundColor = barColor;
      opt1BarLabel.textContent = `${state.batteryPercent} % (${currentAh.toLocaleString('de-DE')} Ah)`;
      opt1MaxCap.textContent = `${state.maxCapacity.toLocaleString('de-DE')} Ah (${state.maxCapacity / 400} Batterien)`;
      opt1CurCap.textContent = `${currentAh.toLocaleString('de-DE')} Ah`;
      
      opt1SolarWatts.textContent = `+ ${totalSolarWatts.toLocaleString('de-DE')} W`;
      opt1WeatherDesc.textContent = `${weatherDesc} (${state.solarRad}%)`;
      opt1BaseLoad.textContent = `- ${state.baseLoad.toLocaleString('de-DE')} W`;
      opt1GenThresh.textContent = `${state.genThreshold} % Batterie-Ladezustand`;

      if (isCharging) {
        opt1Pill.textContent = `LÄDT AUF (+${netWatts} W)`;
        opt1Pill.className = 'pz-status-pill pill-green';
        opt1NetFlow.textContent = `+ ${netWatts.toLocaleString('de-DE')} W (Laden)`;
        opt1NetFlow.className = 'pz-stat-val green';
        opt1TimeEst.textContent = timeEstText;
        opt1TimeEst.className = 'pz-stat-val green';
      } else {
        opt1Pill.textContent = `ENTLADUNG (-${Math.abs(netWatts)} W)`;
        opt1Pill.className = 'pz-status-pill pill-amber';
        opt1NetFlow.textContent = `- ${Math.abs(netWatts).toLocaleString('de-DE')} W (Entladung)`;
        opt1NetFlow.className = 'pz-stat-val amber';
        opt1TimeEst.textContent = timeEstText;
        opt1TimeEst.className = 'pz-stat-val red';
      }
    }

    // ==========================================
    // UPDATE OPTION 2: Vanilla Upgrade
    // ==========================================
    const opt2BarFill = document.getElementById('opt2-bar-fill');
    const opt2BarLabel = document.getElementById('opt2-bar-label');
    const opt2TextCap = document.getElementById('opt2-text-cap');
    const opt2StatusText = document.getElementById('opt2-status-text');
    const opt2TimeEst = document.getElementById('opt2-time-est');
    const opt2SolarWatts = document.getElementById('opt2-solar-watts');
    const opt2Weather = document.getElementById('opt2-weather');
    const opt2BaseLoad = document.getElementById('opt2-base-load');
    const opt2NetFlow = document.getElementById('opt2-net-flow');
    const opt2GenThresh = document.getElementById('opt2-gen-thresh');

    if (opt2BarFill) {
      opt2BarFill.style.width = `${state.batteryPercent}%`;
      opt2BarFill.style.backgroundColor = barColor;
      opt2BarLabel.textContent = `${state.batteryPercent} % (${currentAh.toLocaleString('de-DE')} / ${state.maxCapacity.toLocaleString('de-DE')} Ah)`;
      opt2TextCap.textContent = `${state.batteryPercent}% (${currentAh.toLocaleString('de-DE')} / ${state.maxCapacity.toLocaleString('de-DE')} Ah)`;
      opt2TimeEst.textContent = timeEstText;
      opt2SolarWatts.textContent = `+${totalSolarWatts.toLocaleString('de-DE')} W`;
      opt2Weather.textContent = `${state.solarRad}%`;
      opt2BaseLoad.textContent = `-${state.baseLoad.toLocaleString('de-DE')} W`;
      opt2GenThresh.textContent = `${state.genThreshold} %`;

      if (isCharging) {
        opt2StatusText.textContent = `LÄDT AUF (+${netWatts} W Netto)`;
        opt2StatusText.style.color = '#4ade80';
        opt2NetFlow.textContent = `+${netWatts} W (Speicher lädt)`;
        opt2NetFlow.style.color = '#4ade80';
      } else {
        opt2StatusText.textContent = `ENTLADUNG (-${Math.abs(netWatts)} W Netto)`;
        opt2StatusText.style.color = '#facc15';
        opt2NetFlow.textContent = `-${Math.abs(netWatts)} W (Akku wird leergewirtschaftet)`;
        opt2NetFlow.style.color = '#f87171';
      }
    }

    // ==========================================
    // UPDATE OPTION 3: Bisheriger Status (Old Mod)
    // ==========================================
    const opt3TextPercent = document.getElementById('opt3-text-percent');
    const opt3MaxCap = document.getElementById('opt3-max-cap');
    const opt3SolarWatts = document.getElementById('opt3-solar-watts');
    const opt3BaseLoad = document.getElementById('opt3-base-load');
    const opt3GenThresh = document.getElementById('opt3-gen-thresh');
    const opt3BarFill = document.getElementById('opt3-bar-fill');
    const opt3BarText = document.getElementById('opt3-bar-text');

    if (opt3TextPercent) {
      opt3TextPercent.textContent = `${state.batteryPercent} %`;
      opt3MaxCap.textContent = state.maxCapacity;
      opt3SolarWatts.textContent = totalSolarWatts;
      opt3BaseLoad.textContent = state.baseLoad;
      opt3GenThresh.textContent = state.genThreshold;
      opt3BarFill.style.width = `${state.batteryPercent}%`;
      opt3BarText.textContent = `[|||||||||||||||.....] ${state.batteryPercent}% (${isCharging ? '+' : '-'}${Math.abs(netWatts)} W)`;
    }
  }

  // Bind sliders
  [sliderSolar, sliderCap, sliderLoad, sliderGen].forEach(el => {
    if (el) el.addEventListener('input', updateSimulation);
  });

  // Switch between Option 1, Option 2, and Option 3
  function switchOption(index) {
    [btnOpt1, btnOpt2, btnOpt3].forEach(btn => btn.classList.remove('active'));
    [viewOpt1, viewOpt2, viewOpt3].forEach(view => view.classList.remove('active'));

    if (index === 1) {
      btnOpt1.classList.add('active');
      viewOpt1.classList.add('active');
    } else if (index === 2) {
      btnOpt2.classList.add('active');
      viewOpt2.classList.add('active');
    } else if (index === 3) {
      btnOpt3.classList.add('active');
      viewOpt3.classList.add('active');
    }
  }

  if (btnOpt1) btnOpt1.addEventListener('click', () => switchOption(1));
  if (btnOpt2) btnOpt2.addEventListener('click', () => switchOption(2));
  if (btnOpt3) btnOpt3.addEventListener('click', () => switchOption(3));

  // Initial call
  updateSimulation();
});
