const scopeOptions = ["meeting", "task", "route", "validation", "design", "project"];
const attachmentTypeOptions = ["image", "video", "screenshot", "audio", "document", "other"];
const sensitiveOptions = ["unknown", "no", "yes"];
const reviewOwnerOptions = ["", "security", "design", "qa", "orchestrator", "product", "docs"];

const zoneMap = {
  orchestrator: "reception",
  product: "planning",
  research: "planning",
  cto: "planning",
  design: "planning",
  pm: "planning",
  frontend: "build",
  backend: "build",
  data: "build",
  devops: "build",
  performance: "build",
  qa: "quality",
  validation: "quality",
  reviewer: "quality",
  security: "quality",
  docs: "docs",
  integration: "docs",
};

const desks = {
  orchestrator: { x: 148, y: 182 },
  product: { x: 448, y: 184 },
  research: { x: 604, y: 184 },
  cto: { x: 756, y: 184 },
  design: { x: 520, y: 314 },
  pm: { x: 676, y: 314 },
  frontend: { x: 176, y: 420 },
  backend: { x: 364, y: 420 },
  data: { x: 552, y: 420 },
  devops: { x: 740, y: 420 },
  performance: { x: 460, y: 540 },
  qa: { x: 180, y: 634 },
  validation: { x: 378, y: 634 },
  reviewer: { x: 576, y: 634 },
  security: { x: 774, y: 634 },
  docs: { x: 988, y: 262 },
  integration: { x: 988, y: 492 },
};

const statusColors = {
  idle: "#85909a",
  launching: "#4ea7ff",
  dispatching: "#f3aa3d",
  busy: "#53bd66",
  blocked: "#e05b5b",
  offline: "#4b535c",
};

const statusLabels = {
  available: "idle",
  idle: "idle",
  launching: "launching",
  dispatching: "dispatching",
  dispatched: "dispatching",
  busy: "busy",
  "in-progress": "busy",
  blocked: "blocked",
  offline: "offline",
};

const state = {
  snapshot: null,
  selectedRole: "orchestrator",
  hitTargets: [],
  canvasView: { scale: 1, offsetX: 0, offsetY: 0 },
  animationStart: performance.now(),
};

const elements = {
  tabs: [...document.querySelectorAll(".tab-button")],
  tabPanels: {
    office: document.querySelector("#officeView"),
    media: document.querySelector("#mediaView"),
  },
  openRouteCount: document.querySelector("#openRouteCount"),
  blockerCount: document.querySelector("#blockerCount"),
  workflowPhase: document.querySelector("#workflowPhase"),
  lastRefresh: document.querySelector("#lastRefresh"),
  refreshSnapshot: document.querySelector("#refreshSnapshot"),
  canvas: document.querySelector("#officeCanvas"),
  emptyState: document.querySelector("#officeEmptyState"),
  drawerAgentName: document.querySelector("#drawerAgentName"),
  drawerAgentMeta: document.querySelector("#drawerAgentMeta"),
  drawerStatusPill: document.querySelector("#drawerStatusPill"),
  drawerRole: document.querySelector("#drawerRole"),
  drawerWindow: document.querySelector("#drawerWindow"),
  drawerRoute: document.querySelector("#drawerRoute"),
  drawerLastSeen: document.querySelector("#drawerLastSeen"),
  drawerRefs: document.querySelector("#drawerRefs"),
  routeReportLink: document.querySelector("#routeReportLink"),
  eventTimeline: document.querySelector("#eventTimeline"),
  copyRefs: document.querySelector("#copyRefs"),
  promptForm: document.querySelector("#promptForm"),
  promptMessage: document.querySelector("#promptMessage"),
  recipientSelect: document.querySelector("#recipientSelect"),
  promptResult: document.querySelector("#promptResult"),
  mediaForm: document.querySelector("#mediaForm"),
  commandPreview: document.querySelector("#commandPreview"),
};

function fillSelect(id, options) {
  const select = document.querySelector(`#${id}`);
  for (const option of options) {
    const element = document.createElement("option");
    element.value = option;
    element.textContent = option === "" ? "none" : option;
    select.append(element);
  }
}

function shellQuote(value) {
  if (value === "") {
    return "''";
  }
  if (/^[A-Za-z0-9_./:@%+=,-]+$/.test(value)) {
    return value;
  }
  return `'${value.replace(/'/g, "'\"'\"'")}'`;
}

function addFlag(parts, name, value) {
  if (value) {
    parts.push(name, shellQuote(value));
  }
}

function buildCommand() {
  const data = new FormData(elements.mediaForm);
  const parts = [
    "./scripts/attach-media.sh",
    shellQuote(data.get("meetingId").trim()),
    shellQuote(data.get("scope")),
    shellQuote(data.get("relatedId").trim()),
    shellQuote(data.get("filePath").trim()),
    shellQuote(data.get("attachmentType")),
    shellQuote(data.get("description").trim()),
  ];

  if (data.get("copy") === "on") {
    parts.push("--copy");
  }

  addFlag(parts, "--sensitive", data.get("sensitive"));
  addFlag(parts, "--review-owner", data.get("reviewOwner"));
  addFlag(parts, "--attribution", data.get("attribution").trim());
  addFlag(parts, "--tags", data.get("tags").trim());
  addFlag(parts, "--width", data.get("width").trim());
  addFlag(parts, "--height", data.get("height").trim());
  addFlag(parts, "--mime-type", data.get("mimeType").trim());

  return parts.join(" \\\n  ");
}

function updateCommandPreview() {
  elements.commandPreview.textContent = buildCommand();
}

function statusKey(agent) {
  if (!agent || !agent.live) {
    return "offline";
  }
  return statusLabels[agent.status] || "idle";
}

function statusClass(agent) {
  return `status-${statusKey(agent)}`;
}

function agentByRole(role) {
  return state.snapshot?.agents.find((agent) => agent.role === role) || null;
}

function routeById(routeId) {
  if (!routeId || routeId === "none") {
    return null;
  }
  return state.snapshot?.routes.find((route) => route.route_id === routeId) || null;
}

function formatRelative(value) {
  if (!value) {
    return "-";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  const seconds = Math.max(0, Math.round((Date.now() - date.getTime()) / 1000));
  if (seconds < 60) {
    return `${seconds}s ago`;
  }
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) {
    return `${minutes}m ago`;
  }
  const hours = Math.round(minutes / 60);
  return `${hours}h ago`;
}

function roleZone(role) {
  return zoneMap[role] || "build";
}

function stableDesk(agent, index) {
  if (desks[agent.role]) {
    return desks[agent.role];
  }
  const column = index % 4;
  const row = Math.floor(index / 4);
  return { x: 200 + column * 180, y: 220 + row * 120 };
}

function drawPixelText(ctx, text, x, y, color = "#d8dee5", size = 14) {
  ctx.fillStyle = color;
  ctx.font = `${size}px "SFMono-Regular", Consolas, monospace`;
  ctx.textBaseline = "top";
  ctx.fillText(text, x, y);
}

function drawPanelLabel(ctx, text, x, y, width, accent = "#1f3538") {
  ctx.fillStyle = "#070a0d";
  ctx.strokeStyle = "#3c4650";
  ctx.lineWidth = 2;
  ctx.fillRect(x, y, width, 28);
  ctx.strokeRect(x + 0.5, y + 0.5, width - 1, 27);
  drawPixelText(ctx, text, x + 12, y + 7, "#dce5ec", 13);
  ctx.fillStyle = accent;
  ctx.fillRect(x, y + 26, width, 2);
}

function drawDesk(ctx, x, y, width = 132, height = 62) {
  ctx.fillStyle = "#7a5837";
  ctx.fillRect(x - width / 2, y + 16, width, height);
  ctx.fillStyle = "#9a7045";
  ctx.fillRect(x - width / 2 + 8, y + 22, width - 16, 12);
  ctx.fillStyle = "#443326";
  ctx.fillRect(x - width / 2 + 14, y + height + 10, 16, 24);
  ctx.fillRect(x + width / 2 - 30, y + height + 10, 16, 24);
  ctx.fillStyle = "#1d262d";
  ctx.fillRect(x - 22, y + 2, 44, 26);
  ctx.fillStyle = "#31c2b2";
  ctx.fillRect(x - 16, y + 8, 32, 12);
}

function drawAgent(ctx, agent, x, y, t, selected) {
  const key = statusKey(agent);
  const color = statusColors[key] || statusColors.idle;
  const bob = key === "busy" || key === "dispatching" ? Math.sin(t / 180 + x) * 2 : 0;
  const offsetY = y - 28 + bob;

  if (selected) {
    ctx.strokeStyle = "#35d3c8";
    ctx.lineWidth = 3;
    ctx.strokeRect(x - 43, y - 38, 86, 88);
  }

  ctx.fillStyle = key === "offline" ? "#30363d" : "#26323a";
  ctx.fillRect(x - 21, offsetY + 20, 42, 34);
  ctx.fillStyle = key === "offline" ? "#58606a" : "#d59a63";
  ctx.fillRect(x - 17, offsetY - 6, 34, 30);
  ctx.fillStyle = key === "offline" ? "#333b43" : "#312017";
  ctx.fillRect(x - 19, offsetY - 10, 38, 12);
  ctx.fillRect(x - 21, offsetY - 2, 8, 16);
  ctx.fillRect(x + 13, offsetY - 2, 8, 16);
  ctx.fillStyle = "#101418";
  ctx.fillRect(x - 8, offsetY + 4, 5, 5);
  ctx.fillRect(x + 5, offsetY + 4, 5, 5);
  ctx.fillStyle = color;
  ctx.fillRect(x - 26, y + 42, 52, 6);

  if (key === "blocked") {
    ctx.fillStyle = "#e05b5b";
    ctx.fillRect(x + 29, y + 18, 18, 18);
    drawPixelText(ctx, "!", x + 35, y + 19, "#140809", 14);
  } else if (key === "dispatching") {
    ctx.fillStyle = "#f3aa3d";
    ctx.fillRect(x + 27, y + 20, 22, 14);
    drawPixelText(ctx, ">", x + 34, y + 19, "#160d02", 13);
  } else if (key === "launching") {
    ctx.fillStyle = "#4ea7ff";
    ctx.fillRect(x + 27, y + 20, 22, 14);
    drawPixelText(ctx, "^", x + 34, y + 19, "#04101d", 13);
  }

  const label = agent.display_name || agent.role;
  const shortLabel = label.length > 15 ? `${label.slice(0, 14)}.` : label;
  const route = agent.active_route && agent.active_route !== "none" ? agent.active_route : key;
  ctx.fillStyle = "#070a0d";
  ctx.strokeStyle = color;
  ctx.lineWidth = selected ? 2 : 1;
  ctx.fillRect(x - 50, y + 54, 100, 38);
  ctx.strokeRect(x - 49.5, y + 54.5, 99, 37);
  drawPixelText(ctx, shortLabel, x - 42, y + 60, "#e6edf3", 11);
  drawPixelText(ctx, route, x - 42, y + 75, color, 11);
}

function drawOffice(ctx, t) {
  const cssWidth = elements.canvas.clientWidth;
  const cssHeight = elements.canvas.clientHeight;
  const width = 1180;
  const height = 760;
  const scale = Math.min(cssWidth / width, cssHeight / height);
  const offsetX = Math.max(0, (cssWidth - width * scale) / 2);
  const offsetY = Math.max(0, (cssHeight - height * scale) / 2);
  state.canvasView = { scale, offsetX, offsetY };

  ctx.clearRect(0, 0, cssWidth, cssHeight);
  ctx.fillStyle = "#171c21";
  ctx.fillRect(0, 0, cssWidth, cssHeight);

  ctx.save();
  ctx.translate(offsetX, offsetY);
  ctx.scale(scale, scale);

  ctx.fillStyle = "#171c21";
  ctx.fillRect(0, 0, width, height);
  ctx.strokeStyle = "#242b31";
  ctx.lineWidth = 1;
  for (let x = 0; x < width; x += 24) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, height);
    ctx.stroke();
  }
  for (let y = 0; y < height; y += 24) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();
  }

  const zones = [
    { label: "ORCHESTRATOR RECEPTION", x: 28, y: 44, w: 250, h: 242, accent: "#2ba99d" },
    { label: "PLANNING TABLE", x: 318, y: 44, w: 540, h: 242, accent: "#d19a38" },
    { label: "BUILD DESKS", x: 28, y: 328, w: 830, h: 238, accent: "#3b94d9" },
    { label: "QUALITY BAY", x: 28, y: 604, w: 830, h: 132, accent: "#d7b04a" },
    { label: "DOCS / INTEGRATION", x: 904, y: 44, w: 246, h: 692, accent: "#74b37c" },
  ];
  for (const zone of zones) {
    ctx.fillStyle = "rgba(255,255,255,0.025)";
    ctx.strokeStyle = "#39434a";
    ctx.lineWidth = 2;
    ctx.fillRect(zone.x, zone.y, zone.w, zone.h);
    ctx.strokeRect(zone.x + 0.5, zone.y + 0.5, zone.w - 1, zone.h - 1);
    drawPanelLabel(ctx, zone.label, zone.x + 16, zone.y + 16, Math.min(zone.w - 32, 234), zone.accent);
  }

  drawDesk(ctx, 148, 176, 150, 72);
  drawDesk(ctx, 604, 174, 276, 90);
  for (const role of ["frontend", "backend", "data", "devops", "performance", "qa", "validation", "reviewer", "security", "docs", "integration"]) {
    const desk = desks[role];
    drawDesk(ctx, desk.x, desk.y, roleZone(role) === "docs" ? 128 : 132, 58);
  }

  ctx.fillStyle = "#202831";
  ctx.fillRect(954, 112, 146, 56);
  drawPixelText(ctx, ".agents", 976, 125, "#74b37c", 13);
  drawPixelText(ctx, "routes", 976, 143, "#74b37c", 13);

  state.hitTargets = [];
  const agents = state.snapshot?.agents || [];
  agents.forEach((agent, index) => {
    const desk = stableDesk(agent, index);
    const selected = agent.role === state.selectedRole;
    drawAgent(ctx, agent, desk.x, desk.y, t, selected);
    state.hitTargets.push({ role: agent.role, x: desk.x, y: desk.y + 30, radius: 58 });
  });
  ctx.restore();
}

function resizeCanvas() {
  const canvas = elements.canvas;
  const rect = canvas.getBoundingClientRect();
  const ratio = window.devicePixelRatio || 1;
  const cssWidth = Math.max(640, Math.round(rect.width));
  const cssHeight = Math.max(520, Math.round(rect.height));
  if (canvas.width !== Math.round(cssWidth * ratio) || canvas.height !== Math.round(cssHeight * ratio)) {
    canvas.width = Math.round(cssWidth * ratio);
    canvas.height = Math.round(cssHeight * ratio);
  }
  const ctx = canvas.getContext("2d");
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
}

function animateOffice(now) {
  resizeCanvas();
  const ctx = elements.canvas.getContext("2d");
  drawOffice(ctx, now - state.animationStart);
  requestAnimationFrame(animateOffice);
}

function updateStatusStrip() {
  const workflow = state.snapshot?.workflow || {};
  const openRoutes = workflow.open_routes || [];
  const blockedRows = workflow.blocked_tasks || [];
  const routeBlockers = (state.snapshot?.routes || []).filter((route) => route.status === "blocked");
  elements.openRouteCount.textContent = String(openRoutes.length || (state.snapshot?.routes || []).filter((route) => route.status !== "done" && route.status !== "cancelled").length);
  elements.blockerCount.textContent = String(blockedRows.length + routeBlockers.length);
  elements.workflowPhase.textContent = workflow.phase || "-";
  elements.lastRefresh.textContent = formatRelative(state.snapshot?.generated_at);
  elements.emptyState.hidden = (state.snapshot?.agents || []).some((agent) => agent.live);
}

function refsForAgent(agent) {
  if (!agent) {
    return "No selected agent.";
  }
  const lines = [
    `Role: ${agent.role}`,
    `Status: ${statusKey(agent)}`,
    `Profile: ${agent.profile_path || "none"}`,
    `Memory: ${agent.memory_path || "none"}`,
    `Inbox: ${agent.inbox_path || "none"}`,
    `Telemetry: .agents/state/agents.jsonl`,
    `Events: .agents/events.jsonl`,
  ];
  if (agent.active_route && agent.active_route !== "none") {
    lines.push(`Route report: .agents/routes/${agent.active_route}.md`);
    lines.push(`Status command: ./scripts/route-status.sh ${agent.active_route}`);
  }
  return lines.join("\n");
}

function eventsForAgent(agent) {
  if (!agent || !state.snapshot) {
    return [];
  }
  const activeRoute = agent.active_route;
  return [...state.snapshot.events]
    .reverse()
    .filter((event) => {
      return event.actor === agent.role || event.correlation_id === activeRoute || event.details?.includes?.(agent.role) || event.summary?.includes?.(agent.role);
    })
    .slice(0, 6);
}

function updateDrawer() {
  const agent = agentByRole(state.selectedRole) || state.snapshot?.agents[0] || null;
  if (agent && state.selectedRole !== agent.role) {
    state.selectedRole = agent.role;
  }

  elements.recipientSelect.value = state.selectedRole;
  elements.drawerAgentName.textContent = agent?.display_name || "Agent Inspector";
  elements.drawerAgentMeta.textContent = agent ? `${roleZone(agent.role)} zone` : "Select an agent in the office.";
  elements.drawerStatusPill.textContent = statusKey(agent);
  elements.drawerStatusPill.className = `status-pill ${statusClass(agent)}`;
  elements.drawerRole.textContent = agent?.role || "-";
  elements.drawerWindow.textContent = agent ? `${agent.session || "no-session"} / ${agent.window || agent.role}` : "-";
  elements.drawerRoute.textContent = agent?.active_route || "none";
  elements.drawerLastSeen.textContent = formatRelative(agent?.last_seen_at);
  elements.drawerRefs.textContent = refsForAgent(agent);

  const activeRoute = routeById(agent?.active_route);
  if (activeRoute?.report) {
    elements.routeReportLink.href = `../${activeRoute.report}`;
    elements.routeReportLink.hidden = false;
  } else {
    elements.routeReportLink.hidden = true;
  }

  const events = eventsForAgent(agent);
  elements.eventTimeline.innerHTML = "";
  if (events.length === 0) {
    const item = document.createElement("li");
    item.textContent = "No recent matching events.";
    elements.eventTimeline.append(item);
  } else {
    for (const event of events) {
      const item = document.createElement("li");
      const time = document.createElement("time");
      time.textContent = formatRelative(event.timestamp);
      const summary = document.createElement("span");
      summary.textContent = event.summary || event.type || "event";
      item.append(time, summary);
      elements.eventTimeline.append(item);
    }
  }
}

function populateRecipientSelect() {
  const current = elements.recipientSelect.value || state.selectedRole;
  elements.recipientSelect.innerHTML = "";
  for (const agent of state.snapshot?.agents || []) {
    const option = document.createElement("option");
    option.value = agent.role;
    option.textContent = agent.display_name || agent.role;
    elements.recipientSelect.append(option);
  }
  elements.recipientSelect.value = current || state.selectedRole;
}

async function loadSnapshot() {
  elements.refreshSnapshot.disabled = true;
  try {
    const response = await fetch("/api/snapshot", { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Snapshot failed: ${response.status}`);
    }
    state.snapshot = await response.json();
    if (!agentByRole(state.selectedRole)) {
      state.selectedRole = state.snapshot.agents[0]?.role || "orchestrator";
    }
    populateRecipientSelect();
    updateStatusStrip();
    updateDrawer();
  } catch (error) {
    elements.promptResult.textContent = error.message;
  } finally {
    elements.refreshSnapshot.disabled = false;
  }
}

async function submitPrompt(event) {
  event.preventDefault();
  const role = elements.recipientSelect.value || state.selectedRole;
  const message = elements.promptMessage.value.trim();
  elements.promptResult.textContent = "";
  if (!message) {
    elements.promptResult.textContent = "Enter a prompt.";
    return;
  }
  const submit = elements.promptForm.querySelector("button[type='submit']");
  submit.disabled = true;
  try {
    const response = await fetch("/api/orchestrator-prompt", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ role, message }),
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.error || `Request failed: ${response.status}`);
    }
    elements.promptResult.textContent = `Queued ${payload.route_id}`;
    elements.promptMessage.value = "";
    await loadSnapshot();
    state.selectedRole = role;
    updateDrawer();
  } catch (error) {
    elements.promptResult.textContent = error.message;
  } finally {
    submit.disabled = false;
  }
}

async function copySelectedRefs() {
  const text = elements.drawerRefs.textContent;
  try {
    await navigator.clipboard.writeText(text);
    elements.promptResult.textContent = "Refs copied.";
  } catch {
    elements.promptResult.textContent = text;
  }
}

function activateTab(name) {
  for (const tab of elements.tabs) {
    const selected = tab.dataset.tab === name;
    tab.classList.toggle("is-active", selected);
    tab.setAttribute("aria-selected", String(selected));
  }
  for (const [key, panel] of Object.entries(elements.tabPanels)) {
    const selected = key === name;
    panel.classList.toggle("is-active", selected);
    panel.hidden = !selected;
  }
}

function handleCanvasClick(event) {
  const rect = elements.canvas.getBoundingClientRect();
  const rawX = event.clientX - rect.left;
  const rawY = event.clientY - rect.top;
  const x = (rawX - state.canvasView.offsetX) / state.canvasView.scale;
  const y = (rawY - state.canvasView.offsetY) / state.canvasView.scale;
  const target = state.hitTargets.find((hit) => {
    const dx = x - hit.x;
    const dy = y - hit.y;
    return Math.sqrt(dx * dx + dy * dy) < hit.radius;
  });
  if (target) {
    state.selectedRole = target.role;
    updateDrawer();
  }
}

fillSelect("scope", scopeOptions);
fillSelect("attachmentType", attachmentTypeOptions);
fillSelect("sensitive", sensitiveOptions);
fillSelect("reviewOwner", reviewOwnerOptions);

elements.mediaForm.addEventListener("input", updateCommandPreview);
elements.mediaForm.addEventListener("change", updateCommandPreview);
elements.refreshSnapshot.addEventListener("click", loadSnapshot);
elements.promptForm.addEventListener("submit", submitPrompt);
elements.copyRefs.addEventListener("click", copySelectedRefs);
elements.recipientSelect.addEventListener("change", (event) => {
  state.selectedRole = event.target.value;
  updateDrawer();
});
elements.canvas.addEventListener("click", handleCanvasClick);
elements.tabs.forEach((tab) => tab.addEventListener("click", () => activateTab(tab.dataset.tab)));

updateCommandPreview();
requestAnimationFrame(animateOffice);
loadSnapshot();
setInterval(loadSnapshot, 15000);
