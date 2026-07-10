async function loadPorts() {
    const container = document.getElementById('ports-container');
    const countDisplay = document.getElementById('port-count');
    const searchBar = document.getElementById('search-bar');
    const genreDropdown = document.getElementById('genre-filter');
    const availabilityDropdown = document.getElementById('availability-filter');
    const requirementsDropdown = document.getElementById('requirements-filter');
    const runtimeDropdown = document.getElementById('runtime-filter');
    const sortDropdown = document.getElementById('sort-select');
    const recentStrip = document.getElementById('recent-strip');
    const newStrip = document.getElementById('new-strip');
    const devlogContent = document.getElementById('devlog-content');
    const GITHUB_REPO_OWNER = 'JeodC';
    const GITHUB_REPO_NAME = 'RHH-Ports';
    const RECENT_COUNT = 6;
    const NEW_COUNT = 6;
    const DEVLOG_COUNT = 3;

    const runtimeNames = {
        'dotnet-8.0.12.squashfs': '.NET 8',
        'gmloadernext.squashfs': 'GMLoader-Next',
        'gmtoolkit.squashfs': 'GMToolkit',
        'mkxp-z.squashfs': 'MKXP-Z',
        'mono-6.12.0.122-aarch64.squashfs': 'Mono 6.12',
        'python_3.11.squashfs': 'Python 3.11',
        'rlvm-sdl2.squashfs': 'RLVM',
        'solarus-1.6.5.squashfs': 'Solarus',
        'weston_pkg_0.2.squashfs': 'Westonpack',
        'zulu17.54.21-ca-jre17.0.13-linux.squashfs': 'Java 17'
    };

    const mappings = [
        { keys: ['!lowpower'], value: 'Needs moderate CPU' },
        { keys: ['!lowres'], value: 'Needs minimum 640x480 resolution' },
        { keys: ['hires'], value: 'Best on high resolution' },
        { keys: ['power'], value: 'Needs high CPU power' },
        { keys: ['2gb'], value: 'Needs 2GB RAM' },
        { keys: ['4gb', 'ultra'], value: 'Needs > 2GB RAM' },
        { keys: ['opengl'], value: 'Requires mainline OpenGL' },
        { keys: ['vulkan'], value: 'Requires Vulkan' },
        { keys: ['wide'], value: 'Requires widescreen' },
        { keys: ['analog_1', 'analog_2', 'analog_1|analog_2'], value: 'Requires analog sticks' },
        { keys: ['!arkos'], value: 'Won\'t run on ArkOS' }
    ];

    // Store rendering + affiliate-tag injection.
    const STORE_CONFIG = {
        'Steam': {
            priority: 1,
            modifier: 'steam',
            icon: 'fa-brands fa-steam',
            short: 'Steam',
            addAffiliate: (url) => {
                const TAG = '46123857';
                if (!TAG) return url;
                return url + (url.includes('?') ? '&' : '?') + 'curator_clanid=' + encodeURIComponent(TAG);
            }
        },
        'GOG': {
            priority: 2,
            modifier: 'gog',
            icon: '',
            short: 'GOG',
            addAffiliate: (url) => {
                const TAG = '';
                if (!TAG) return url;
                return url + (url.includes('?') ? '&' : '?') + 'pp=' + encodeURIComponent(TAG);
            }
        },
        'Itch.io': {
            priority: 3,
            modifier: 'itch',
            icon: 'fa-brands fa-itch-io',
            short: 'Itch',
            addAffiliate: (url) => url
        },
        'Epic Games': {
            priority: 4,
            modifier: 'epic',
            icon: '',
            short: 'Epic',
            addAffiliate: (url) => {
                const TAG = '';
                if (!TAG) return url;
                return url + (url.includes('?') ? '&' : '?') + 'creatorTag=' + encodeURIComponent(TAG);
            }
        },
        'Humble Store': {
            priority: 5,
            modifier: 'humble',
            icon: '',
            short: 'Humble',
            isPaidAffiliate: true,
            addAffiliate: (url) => {
                const IMPACT_ID = '7306128';
                if (!IMPACT_ID) return url;
                return `https://humblebundleinc.sjv.io/c/${IMPACT_ID}/2059850/25796?u=` + encodeURIComponent(url);
            }
        },
        'Fanatical': {
            priority: 6,
            modifier: 'fanatical',
            icon: '',
            short: 'Fanatical',
            addAffiliate: (url) => url
        }
    };

    // === Discount integration (via Cloudflare Worker proxy) ===
    const DISCOUNT_API_URL = 'https://rhh-ports-discounts.jeodc.workers.dev/';
    const DISCOUNT_COUNTRY = 'US';
    const DISCOUNT_CACHE_KEY = 'rhh:discounts:v3';
    const DISCOUNT_CACHE_TTL_MS = 60 * 60 * 1000;     // 1 hour (Worker also caches 15m on its CDN)

    // Cache is invalidated by either TTL or appid-set drift
    const readCachedDiscounts = (requestedAppids) => {
        try {
            const raw = localStorage.getItem(DISCOUNT_CACHE_KEY);
            if (!raw) return null;
            const cached = JSON.parse(raw);
            if (!cached || (Date.now() - cached.ts) >= DISCOUNT_CACHE_TTL_MS) return null;
            const have = new Set(Object.keys(cached.data || {}));
            if (!requestedAppids.every(id => have.has(String(id)))) return null;
            return cached.data;
        } catch (_) { /* corrupt cache; ignore */ }
        return null;
    };
    const writeCachedDiscounts = (data) => {
        try { localStorage.setItem(DISCOUNT_CACHE_KEY, JSON.stringify({ ts: Date.now(), data })); } catch (_) {}
    };

    // Returns { appid: { shopName: cutPct, ... }, ... } — empty on any failure
    // or timeout. The 3s bound keeps a slow/hung proxy from blocking first paint
    // when we await this before the initial render.
    const DISCOUNT_FETCH_TIMEOUT_MS = 3000;
    const fetchDiscounts = async (steamAppids) => {
        if (!steamAppids.length) return {};
        const cached = readCachedDiscounts(steamAppids);
        if (cached) return cached;
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), DISCOUNT_FETCH_TIMEOUT_MS);
        try {
            const url = `${DISCOUNT_API_URL}?appids=${steamAppids.join(',')}&country=${DISCOUNT_COUNTRY}`;
            const res = await fetch(url, { signal: controller.signal });
            if (!res.ok) throw new Error('discount proxy ' + res.status);
            const data = await res.json();
            writeCachedDiscounts(data);
            return data;
        } catch (err) {
            console.warn('[discounts] fetch failed:', err);
            return {};
        } finally {
            clearTimeout(timer);
        }
    };

    // Populated post-fetch; renderStores reads from it at render time.
    let discountsByAppid = {};

    try {
        // Fetch data concurrently for speed
        const [res, apiRes] = await Promise.all([
            fetch('ports.json', { cache: 'no-cache' }),
            fetch(`https://api.github.com/repos/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/releases`).catch(() => null)
        ]);

        if (!res.ok) throw new Error('Failed to load ports.json');
        const ports = await res.json();
        const releases = apiRes && apiRes.ok ? await apiRes.json() : [];

        // Map asset download counts
        const downloadCounts = {};
        releases.forEach(release => {
            release.assets.forEach(asset => {
                downloadCounts[asset.name] = asset.download_count;
            });
        });

        // --- Dropdown Population ---
        const populateDropdown = (dropdown, values, mapFn = v => v) => {
            values.forEach(v => {
                const opt = document.createElement('option');
                opt.value = v;
                opt.textContent = mapFn(v);
                dropdown.appendChild(opt);
            });
        };

        const genreSet = new Set(ports.flatMap(p => p.attr?.genres || []));
        populateDropdown(genreDropdown, Array.from(genreSet).sort(), g => g.charAt(0).toUpperCase() + g.slice(1));

        const availabilitySet = new Set(ports.map(p => p.attr?.availability).filter(Boolean));
        populateDropdown(availabilityDropdown, Array.from(availabilitySet).sort(), a =>
            ({ full: 'Ready to run', demo: 'Demo files included', free: 'Free, files needed', paid: "Paid, files needed" }[a.toLowerCase()] || a)
        );

        const keyToLabel = {};
        mappings.forEach(m => m.keys.forEach(k => keyToLabel[k.toLowerCase()] = m.value));

        const reqLabels = new Set();
        ports.forEach(p => (p.attr?.reqs || []).forEach(r => {
            const label = keyToLabel[r.toLowerCase()];
            if (label) reqLabels.add(label);
        }));

        const orderedReqs = mappings.map(m => m.value).filter(v => reqLabels.has(v));
        populateDropdown(requirementsDropdown, orderedReqs);

        const runtimeSet = new Set(ports.flatMap(p => p.attr?.runtime || []));
        populateDropdown(runtimeDropdown, Array.from(runtimeSet).sort(), r => runtimeNames[r] || r);

        const escAttr = s => String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

        const renderStores = (stores) => {
            if (!Array.isArray(stores) || stores.length === 0) return '';
            const valid = stores
                .filter(s => s && s.gameurl)
                .map(s => ({ s, cfg: STORE_CONFIG[s.name] || { priority: 99, modifier: 'other', icon: '', short: s.name || 'Buy', addAffiliate: (u) => u } }));
            // Canonical store ordering: Steam, GOG, Itch.io, Epic, then everything else.
            valid.sort((a, b) => (a.cfg.priority ?? 99) - (b.cfg.priority ?? 99));

            // The ITAD discount map is keyed by Steam appid. Find this port's
            // appid (if any) so every store button on the port can pick up its
            // shop-specific discount from the same lookup.
            const steamEntry = valid.find(({ s }) => /store\.steampowered\.com\/app\//.test(s.gameurl));
            const appidMatch = steamEntry && steamEntry.s.gameurl.match(/store\.steampowered\.com\/app\/(\d+)/);
            const portDiscounts = appidMatch ? discountsByAppid[appidMatch[1]] : null;

            const buttons = valid
                .map(({ s, cfg }) => {
                    const url = cfg.addAffiliate(s.gameurl);
                    const label = cfg.short || s.name || 'Buy';
                    const iconHtml = cfg.icon ? `<i class="${cfg.icon}" aria-hidden="true"></i>` : '';
                    const labelHtml = `<span class="port-store-label">${escAttr(label)}</span>`;
                    // Discount precedence: explicit s.discount > ITAD lookup > empty
                    // ITAD entries are { cut: number, url: string } since the Worker
                    // started returning full listings + URLs. Only render a badge
                    // when there's an actual discount (cut > 0).
                    const explicit = s.discount;
                    const itadEntry = portDiscounts ? portDiscounts[s.name] : null;
                    const itadCut = itadEntry && itadEntry.cut > 0 ? itadEntry.cut : null;
                    const pct = explicit || (itadCut ? `-${itadCut}%` : '');
                    const discount = pct ? `<span class="port-store-discount">${escAttr(pct)}</span>` : '<span class="port-store-discount"></span>';
                    const tooltip = s.name
                        ? (cfg.isPaidAffiliate ? `Buy on ${s.name} (affiliate link)` : `Buy on ${s.name}`)
                        : 'Buy';
                    return `<a class="port-store port-store--${cfg.modifier}" href="${escAttr(url)}" target="_blank" rel="noopener noreferrer sponsored" title="${escAttr(tooltip)}" data-store-name="${escAttr(s.name || '')}">${iconHtml}${labelHtml}${discount}</a>`;
                })
                .join('');
            if (!buttons) return '';
            return `<div class="port-stores" aria-label="Buy the game">${buttons}</div>`;
        };

        // Shared tile renderer: same template for the Recently Updated and
        // What's New carousels.
        const renderTile = (p) => {
            const title = p.attr?.title || p.name;
            const screenshot = p.source?.screenshot_url || '';
            const date = (p.source?.date_updated || '').split('T')[0];
            const downloadUrl = p.source?.download_url || '';
            const readmeUrl = p.source?.readme_url || '';
            const filename = downloadUrl ? downloadUrl.split('/').pop() : '';
            const dlSinceUpdate = downloadCounts?.[filename] ?? 0;
            const lastCommit = p.source?.last_commit;
            const meaningfulCommit = (lastCommit && !lastCommit.includes('Update ports.json')) ? lastCommit : '';
            const tooltip = meaningfulCommit || title;
            const href = readmeUrl || downloadUrl || '#';
            return `
                <a class="recent-tile" href="${href}" target="_blank" rel="noopener noreferrer" title="${escAttr(tooltip)}" data-readme="${escAttr(readmeUrl)}" data-port-title="${escAttr(title)}">
                    <img src="${screenshot}" alt="${title} screenshot" loading="lazy">
                    <div class="recent-tile-info">
                        <div class="recent-tile-title">${title}</div>
                        <div class="recent-tile-date">${date} | ${dlSinceUpdate} ↓ since update</div>
                        ${meaningfulCommit ? `<div class="recent-tile-commit">${escAttr(meaningfulCommit)}</div>` : ''}
                    </div>
                </a>`;
        };

        // --- Recently Updated Carousel ---
        const renderRecentStrip = () => {
            if (!recentStrip) return;
            const recent = [...ports]
                .filter(p => p.source?.date_updated)
                .sort((a, b) => new Date(b.source.date_updated) - new Date(a.source.date_updated))
                .slice(0, RECENT_COUNT);

            recentStrip.innerHTML = recent.map(renderTile).join('');
        };

        // --- "What's New" Carousel: the N most-recently-added ports by
        //     first_seen. Always shows N tiles; never hides the section. ---
        const renderNewStrip = () => {
            if (!newStrip) return;
            const fresh = [...ports]
                .filter(p => p.source?.first_seen)
                .sort((a, b) => (b.source.first_seen || '').localeCompare(a.source.first_seen || ''))
                .slice(0, NEW_COUNT);

            newStrip.innerHTML = fresh.map(renderTile).join('');
        };

        // --- Devlog ---
        const renderDevlog = async () => {
            if (!devlogContent) return;
            try {
                const res = await fetch('devlog/index.json', { cache: 'no-cache' });
                if (!res.ok) throw new Error('manifest missing');
                const data = await res.json();
                const allPosts = (data.posts || [])
                    .sort((a, b) => (b.date || '').localeCompare(a.date || ''));
                const posts = allPosts.slice(0, DEVLOG_COUNT);

                if (posts.length === 0) {
                    devlogContent.innerHTML = '<p class="devlog-empty">No devlog posts yet.</p>';
                    return;
                }

                const postsHtml = posts.map(p => `
                    <article class="devlog-post">
                        <header>
                            <h3>${p.title}</h3>
                            <time>${p.date}</time>
                        </header>
                        ${p.excerpt ? `<p class="devlog-excerpt">${p.excerpt}</p>` : ''}
                        <button type="button" class="devlog-readmore" data-slug="${escAttr(p.slug)}" data-title="${escAttr(p.title)}">Read more →</button>
                    </article>
                `).join('');

                const olderHtml = `<p class="devlog-older"><a href="https://github.com/JeodC/RHH-Ports/tree/main/docs/devlog" target="_blank" rel="noopener noreferrer">Older posts →</a></p>`;

                devlogContent.innerHTML = postsHtml + olderHtml;
                // "Read more →" opens the full post in the shared README modal
                // (wired via delegation on devlogContent once the modal helpers exist).
            } catch (err) {
                devlogContent.innerHTML = '<p class="devlog-empty">Devlog unavailable.</p>';
            }
        };

        renderRecentStrip();
        renderNewStrip();
        renderDevlog();

        // --- Core Functions ---
        const renderPorts = (filtered) => {
            const genreVal = genreDropdown.value;
            const availabilityVal = availabilityDropdown.value;
            const reqVal = requirementsDropdown.value;

            let countText = `${filtered.length} released ports`;
            if (genreVal !== 'all') countText += ` in "${genreDropdown.selectedOptions[0].text}"`;
            countDisplay.textContent = countText;

            container.innerHTML = filtered.map(port => {
                const title = port.attr.title || port.name;
                const screenshot = port.source.screenshot_url || '';
                const downloadHref = port.source.download_url || '';
                const filename = downloadHref ? downloadHref.split('/').pop() : '';
                const baseLifetime = port.source?.lifetime_downloads ?? 0;
                const downloadCount = downloadCounts?.[filename] ?? 0;
                const totalLifetime = baseLifetime + downloadCount;
                const reqs = (port.attr?.reqs || []).join(', ');
                const genres = (port.attr?.genres || []).join(', ');
                const runtimes = (port.attr?.runtime || []).map(r => runtimeNames[r] || r).join(', ');
                const lastCommit = port.source.last_commit;
                const displayCommit = (!lastCommit || lastCommit.includes('Update ports.json')) 
                    ? "" 
                    : lastCommit;

                return `
                    <div class="port-card">
                        <img src="${screenshot}" alt="${title} screenshot" loading="lazy">
                        <div class="port-info">
                            <h2 class="port-title">${title}</h2>
                            <p class="port-desc">${port.attr.desc || ''}</p>
                            <div class="port-footer">
                                <p class="download-count">
                                    <strong>Downloads since last update:</strong> ${downloadCount}</br>
                                    <strong>Total Downloads:</strong> ${totalLifetime}
                                </p>
                                ${reqs ? `<div class="port-reqs">${reqs}</div>` : ''}
                                ${runtimes ? `<div class="port-runtimes">${runtimes}</div>` : ''}
                                ${genres ? `<div class="port-genres">${genres}</div>` : ''}
                                ${displayCommit ? `<div class="port-commit-banner" title="${displayCommit}">${displayCommit}</div>` : ''}
                                ${renderStores(port.attr?.store)}
                                <div class="port-buttons">
                                    <a class="details-link" href="${port.source.readme_url || ''}" target="_blank" rel="noopener noreferrer">Details</a>
                                    <a class="download-link" href="${downloadHref}" target="_blank" rel="noopener noreferrer">Download</a>
                                </div>
                            </div>
                        </div>
                    </div>`;
            }).join('');
        };

        const updateDisplay = () => {
            const genre = genreDropdown.value;
            const availability = availabilityDropdown.value;
            const reqLabel = requirementsDropdown.value;
            const runtime = runtimeDropdown.value;
            const query = searchBar.value.trim().toLowerCase();

            const filtered = ports.filter(p => {
                const pReqs = (p.attr?.reqs || []).map(r => r.toLowerCase());
                if (genre !== 'all' && !p.attr?.genres?.includes(genre)) return false;
                if (availability !== 'all' && p.attr?.availability !== availability) return false;

                // Fixed requirements check
                if (reqLabel !== 'all') {
                    const mapsToSelected = pReqs.some(key => keyToLabel[key] === reqLabel);
                    if (!mapsToSelected) return false;
                }

                if (runtime !== 'all' && !(p.attr?.runtime || []).includes(runtime)) return false;

                if (query && !(p.attr.title || '').toLowerCase().includes(query)) return false;
                return true;
            });

            // Helper: deepest active discount across all of a port's stores.
            // Returns 0 when nothing is on sale (so ports without discounts
            // naturally fall to the bottom of the "biggest discount" sort).
            const bestDiscountForPort = (port) => {
                const stores = port.attr?.store || [];
                const steamEntry = stores.find(s => s && /store\.steampowered\.com\/app\//.test(s.gameurl || ''));
                const m = steamEntry && steamEntry.gameurl.match(/store\.steampowered\.com\/app\/(\d+)/);
                const shops = m ? discountsByAppid[m[1]] : null;
                if (!shops) return 0;
                let best = 0;
                for (const s of stores) {
                    const entry = shops[s.name];
                    const cut = entry && typeof entry === 'object' ? entry.cut : entry;
                    if (cut && cut > best) best = cut;
                }
                return best;
            };

            // Sorting
            const method = sortDropdown.value;
            const sorted = [...filtered].sort((a, b) => {
                if (method === 'most_recent') {
                    return new Date(b.source?.date_updated) - new Date(a.source?.date_updated);
                } else if (method === 'most_downloaded') {
                    const keyA = a.source?.download_url?.split('/').pop();
                    const keyB = b.source?.download_url?.split('/').pop();
                    const countA = (a.source?.lifetime_downloads ?? 0) + (downloadCounts?.[keyA] ?? 0);
                    const countB = (b.source?.lifetime_downloads ?? 0) + (downloadCounts?.[keyB] ?? 0);
                    return countB - countA;
                } else if (method === 'biggest_discount') {
                    const diffA = bestDiscountForPort(a);
                    const diffB = bestDiscountForPort(b);
                    if (diffA !== diffB) return diffB - diffA;
                    // Tie-break on title so the order is deterministic
                    return (a.attr?.title || '').localeCompare(b.attr?.title || '');
                }
                return (a.attr?.title || '').localeCompare(b.attr?.title || '');
            });

            renderPorts(sorted);
        };

        // Listeners
        [searchBar, genreDropdown, availabilityDropdown, requirementsDropdown, runtimeDropdown, sortDropdown]
            .forEach(el => el.addEventListener('input', updateDisplay));

        // Await ITAD discounts before the first render so the default
        // "biggest discount" sort has real data on the initial paint.
        // fetchDiscounts caps itself at 3s and returns {} on error/timeout,
        // so a slow proxy can't hang the page.
        const appids = new Set();
        ports.forEach(p => {
            (p.attr?.store || []).forEach(s => {
                const m = s && s.gameurl && s.gameurl.match(/store\.steampowered\.com\/app\/(\d+)/);
                if (m) appids.add(m[1]);
            });
        });
        if (appids.size) {
            discountsByAppid = await fetchDiscounts([...appids]);
        }

        updateDisplay();

        // --- README Modal ---
        const readmeModal = document.getElementById('readme-modal');
        const readmeTitle = readmeModal?.querySelector('.readme-modal-title');
        const readmeFrame = readmeModal?.querySelector('.readme-modal-frame');
        const readmeClose = readmeModal?.querySelector('.readme-modal-close');

        const closeReadmeModal = () => {
            if (!readmeModal) return;
            readmeModal.setAttribute('hidden', '');
            readmeModal.setAttribute('aria-hidden', 'true');
            if (readmeFrame) readmeFrame.srcdoc = '';
            document.body.style.overflow = '';
        };

        const openReadmeModal = async (url, title, storesHtml = '') => {
            if (!readmeModal) return;
            readmeTitle.textContent = title || 'README';
            const storesSlot = readmeModal.querySelector('.readme-modal-stores');
            if (storesSlot) storesSlot.innerHTML = storesHtml || '';
            readmeFrame.srcdoc = '<html><body style="font-family:system-ui;padding:1rem;color:#666;margin:0">Loading…</body></html>';
            readmeModal.removeAttribute('hidden');
            readmeModal.setAttribute('aria-hidden', 'false');
            document.body.style.overflow = 'hidden';

            try {
                const res = await fetch(url, { cache: 'no-cache' });
                if (!res.ok) throw new Error('not found');
                const md = await res.text();
                const html = (typeof marked !== 'undefined')
                    ? marked.parse(md, { gfm: true, breaks: true })
                    : `<pre>${md.replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]))}</pre>`;
                // Strip the filename so relative paths in the README resolve against the README's directory
                const baseUrl = url.replace(/[^/]+$/, '');
                readmeFrame.srcdoc = `<!DOCTYPE html>
<html><head>
<base href="${baseUrl}" target="_blank">
<style>
body { font-family: system-ui, sans-serif; padding: 1rem 1.5rem; line-height: 1.6; color: #222; margin: 0; word-wrap: break-word; background: #ebe7d9; }
h1, h2, h3, h4 { margin-top: 1.2rem; margin-bottom: 0.5rem; }
h1:first-child, h2:first-child { margin-top: 0; }
p { margin: 0.6rem 0; }
code { background: rgba(0,0,0,0.07); padding: 0.1rem 0.35rem; border-radius: 3px; font-family: ui-monospace, monospace; font-size: 0.9em; }
pre { background: rgba(0,0,0,0.07); padding: 0.8rem; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; }
img { max-width: 100%; height: auto; }
table { border-collapse: collapse; margin: 0.8rem 0; }
th, td { border: 1px solid rgba(0,0,0,0.2); padding: 0.3rem 0.6rem; text-align: left; }
a { color: #3a6ea5; }
blockquote { border-left: 4px solid #3a6ea5; margin: 0.6rem 0; padding: 0.2rem 0.8rem; color: #333; }
ul, ol { padding-left: 1.5rem; }
hr { border: none; border-top: 1px solid rgba(0,0,0,0.15); margin: 1.5rem 0; }
</style>
</head><body>${html}</body></html>`;
            } catch (err) {
                readmeFrame.srcdoc = `<html><body style="font-family:system-ui;padding:1rem;color:#a00;margin:0">Could not load README.</body></html>`;
            }
        };

        // Wire close handlers (once)
        readmeClose?.addEventListener('click', closeReadmeModal);
        readmeModal?.addEventListener('click', (e) => {
            if (e.target === readmeModal) closeReadmeModal();
        });
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && readmeModal && !readmeModal.hasAttribute('hidden')) {
                closeReadmeModal();
            }
        });

        // Delegate Details clicks to the modal opener
        container.addEventListener('click', (e) => {
            const link = e.target.closest('.details-link');
            if (!link) return;
            e.preventDefault();
            const url = link.getAttribute('href');
            if (!url) return;
            const card = link.closest('.port-card');
            const title = card?.querySelector('.port-title')?.textContent || 'README';
            // Clone the card's already-rendered store row (preserves any
            // discount badges populated post-render by the sale tracker).
            const storesEl = card?.querySelector('.port-stores');
            const storesHtml = storesEl ? storesEl.outerHTML : '';
            openReadmeModal(url, title, storesHtml);
        });

        // Carousel tiles open the README modal when clicked. If a port has
        // no README, data-readme is empty and the default link behavior
        // takes over (the href falls back to the download URL).
        const wireTileClicks = (strip) => {
            strip?.addEventListener('click', (e) => {
                const tile = e.target.closest('.recent-tile');
                if (!tile) return;
                const readme = tile.getAttribute('data-readme');
                if (!readme) return;
                e.preventDefault();
                const title = tile.getAttribute('data-port-title') || 'README';
                // Carousel tiles don't have a store row baked into them;
                // re-render fresh from the source port's data.
                const port = ports.find(p => (p.attr?.title || p.name) === title);
                const storesHtml = port ? renderStores(port.attr?.store) : '';
                openReadmeModal(readme, title, storesHtml);
            });
        };
        wireTileClicks(recentStrip);
        wireTileClicks(newStrip);

        devlogContent?.addEventListener('click', (e) => {
            const btn = e.target.closest('.devlog-readmore');
            if (!btn) return;
            const slug = btn.dataset.slug;
            if (!slug) return;
            openReadmeModal(`devlog/${slug}.md`, btn.dataset.title || "Developer's Log");
        });

    } catch (err) {
        container.textContent = 'Error loading ports: ' + err.message;
    }
}

loadPorts();
