// ========================================================
// Desktop & Web Marketing, Lamsa Showcase & Card Motion
// ========================================================
(function() {
    'use strict';

    const LAMSA_UI_STRINGS = {
        en: {
            badgeText: 'Live Contactless Preview',
            pause: 'Pause',
            play: 'Play',
            pauseTitle: 'Pause animation',
            playTitle: 'Play animation',
            standbyTitle: 'Hold Card to Scan',
            standbySub: 'READY TO SCAN',
            sensorLabel: 'NFC Sensor Ready',
            successTitle: 'NFC Tag Detected',
            tabs: ['5★ Review', 'Guest Wi-Fi', 'Card Protection']
        },
        ar: {
            badgeText: 'معاينة التلامس المباشرة',
            pause: 'إيقاف',
            play: 'تشغيل',
            pauseTitle: 'إيقاف الحركة مؤقتاً',
            playTitle: 'تشغيل الحركة',
            standbyTitle: 'قرّب البطاقة للمسح',
            standbySub: 'READY TO SCAN',
            sensorLabel: 'حساس NFC جاهز',
            successTitle: 'تمت قراءة البطاقة',
            tabs: ['تقييم 5 نجوم', 'بطاقة واي فاي', 'حماية البطاقات']
        }
    };

    const CARD_MODELS = [
        {
            id: 'review',
            accent: '#8b5cf6',
            accentLight: '#c4b5fd',
            accentRgb: '139, 92, 246',
            brand: 'Quick NFC',
            clientEn: '5-Star Review Card',
            clientAr: 'بطاقة تقييم Google',
            successSubEn: '5-STAR REVIEW OPENED',
            successSubAr: 'تم فتح نافذة التقييم',
            chip: 'NFC Tag',
            svgPath: '<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" fill="currentColor"/>'
        },
        {
            id: 'wifi',
            accent: '#8b5cf6',
            accentLight: '#c4b5fd',
            accentRgb: '139, 92, 246',
            brand: 'Quick NFC',
            clientEn: 'Wi-Fi Card',
            clientAr: 'بطاقة Wi-Fi',
            successSubEn: 'GUEST WI-FI CONNECTED',
            successSubAr: 'تم الاتصال بالشبكة بنجاح',
            chip: 'NFC Tag',
            svgPath: '<path d="M12 4.5C7 4.5 2.73 6.53 0 9.79L12 21.5 24 9.79C21.27 6.53 17 4.5 12 4.5zm0 4c3.08 0 5.89 1.15 8.04 3.05L12 19.1l-8.04-7.55C6.11 9.65 8.92 8.5 12 8.5z" fill="currentColor"/>'
        },
        {
            id: 'vip',
            accent: '#8b5cf6',
            accentLight: '#c4b5fd',
            accentRgb: '139, 92, 246',
            brand: 'Quick NFC',
            clientEn: 'Card Tamper Protection',
            clientAr: 'حماية للبطاقات من التعديل',
            successSubEn: 'NFC CARD AUTHENTICATED',
            successSubAr: 'تم التحقق من البطاقة الذكية',
            chip: 'NFC Tag',
            svgPath: '<path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-1.5 14.5l-3.5-3.5 1.41-1.41L10.5 12.67l5.09-5.09L17 9l-6.5 6.5z" fill="currentColor"/>'
        }
    ];

    function getUiStrings() {
        const isArabic = document.documentElement.lang === 'ar' || document.documentElement.dir === 'rtl';
        return { isArabic, strings: isArabic ? LAMSA_UI_STRINGS.ar : LAMSA_UI_STRINGS.en };
    }

    function initNavbarAndScrollTop() {
        const desktopNavbar = document.getElementById('desktopNavbar');
        if (desktopNavbar) {
            window.addEventListener('scroll', () => {
                desktopNavbar.classList.toggle('scrolled', window.scrollY > 20);
            }, { passive: true });
        }

        const footerBackToTop = document.getElementById('footerBackToTop');
        if (footerBackToTop) {
            footerBackToTop.addEventListener('click', (e) => {
                e.preventDefault();
                window.scrollTo({ top: 0, behavior: 'smooth' });
            });
        }
    }

    function initLamsaShowcase() {
        const showcaseEl = document.getElementById('heroShowcase');
        const cardEl = document.getElementById('lamsaNfcCard');
        const phoneEl = document.getElementById('lamsaPhone');
        const ripplesEl = document.getElementById('lamsaRipples');
        const toggleBtn = document.getElementById('heroAnimToggle');
        if (!showcaseEl || !cardEl || !phoneEl || !ripplesEl) return;

        const motionQuery = window.matchMedia('(prefers-reduced-motion: no-preference)');
        const tabButtons = Array.from(showcaseEl.querySelectorAll('.lamsa-dot-btn'));

        let currentIndex = 0;
        let isPaused = !motionQuery.matches;
        let stepTimer = null;
        let slideTimer = null;

        function clearTimers() {
            if (stepTimer) {
                clearTimeout(stepTimer);
                stepTimer = null;
            }
            if (slideTimer) {
                clearTimeout(slideTimer);
                slideTimer = null;
            }
        }

        function setTapState(active) {
            if (active) {
                phoneEl.classList.remove('phone-resting-mode', 'animate-phone-tap');
                cardEl.classList.remove('is-tapping');
                ripplesEl.classList.remove('is-active');
                void phoneEl.offsetWidth;
                phoneEl.classList.add('animate-phone-tap');
                cardEl.classList.add('is-tapping');
                ripplesEl.classList.add('is-active');
            } else {
                phoneEl.classList.remove('animate-phone-tap');
                phoneEl.classList.add('phone-resting-mode');
                cardEl.classList.remove('is-tapping');
                ripplesEl.classList.remove('is-active');
            }
        }

        function renderCardAndLocale() {
            const model = CARD_MODELS[currentIndex];
            const { isArabic, strings } = getUiStrings();

            showcaseEl.style.setProperty('--card-accent', model.accent);
            showcaseEl.style.setProperty('--card-accent-light', model.accentLight);
            showcaseEl.style.setProperty('--card-accent-rgb', model.accentRgb);

            const setText = (id, text) => {
                const el = document.getElementById(id);
                if (el) el.textContent = text;
            };

            setText('lamsaBadgeText', strings.badgeText);
            setText('lamsaChipBadge', model.chip);
            setText('lamsaCardBrand', model.brand);
            setText('lamsaClientName', isArabic ? model.clientAr : model.clientEn);
            setText('lamsaCardChip', model.chip);
            setText('lamsaStandbyTitle', strings.standbyTitle);
            setText('lamsaStandbySub', strings.standbySub);
            setText('lamsaSensorLabel', strings.sensorLabel);
            setText('lamsaSuccessTitle', strings.successTitle);
            setText('lamsaSuccessSub', isArabic ? model.successSubAr : model.successSubEn);

            const svgEl = document.getElementById('lamsaCardSvg');
            if (svgEl) svgEl.innerHTML = model.svgPath;

            tabButtons.forEach((btn, idx) => {
                const isSelected = idx === currentIndex;
                btn.classList.toggle('active', isSelected);
                btn.setAttribute('aria-selected', String(isSelected));
                if (strings.tabs[idx]) btn.textContent = strings.tabs[idx];
            });

            if (toggleBtn) updateToggleUi(strings);
        }

        function updateToggleUi(strings) {
            if (!toggleBtn) return;
            const labelEl = document.getElementById('heroAnimToggleLabel');
            const pauseIcon = toggleBtn.querySelector('.icon-pause');
            const playIcon = toggleBtn.querySelector('.icon-play');
            if (labelEl) labelEl.textContent = isPaused ? strings.play : strings.pause;
            toggleBtn.title = isPaused ? strings.playTitle : strings.pauseTitle;
            if (pauseIcon) pauseIcon.style.display = isPaused ? 'none' : 'block';
            if (playIcon) playIcon.style.display = isPaused ? 'block' : 'none';
        }

        function scheduleNextSlide() {
            if (isPaused) return;
            stepTimer = setTimeout(() => {
                if (isPaused) return;
                cardEl.classList.add('is-sliding');
                slideTimer = setTimeout(() => {
                    currentIndex = (currentIndex + 1) % CARD_MODELS.length;
                    renderCardAndLocale();
                    cardEl.classList.remove('is-sliding');
                    if (!isPaused) runCycle(1200);
                }, 400);
            }, 1400);
        }

        function runCycle(standbyDelayMs) {
            clearTimers();
            if (isPaused) return;

            stepTimer = setTimeout(() => {
                if (isPaused) return;
                setTapState(true);

                stepTimer = setTimeout(() => {
                    setTapState(false);
                    scheduleNextSlide();
                }, 3400);
            }, standbyDelayMs);
        }

        if (toggleBtn) {
            toggleBtn.addEventListener('click', () => {
                isPaused = !isPaused;
                const { strings } = getUiStrings();
                updateToggleUi(strings);
                if (isPaused) {
                    clearTimers();
                    cardEl.classList.remove('is-sliding');
                    setTapState(false);
                } else {
                    runCycle(250);
                }
            });
        }

        tabButtons.forEach((btn, idx) => {
            btn.addEventListener('click', () => {
                clearTimers();
                setTapState(false);
                if (idx !== currentIndex) {
                    cardEl.classList.add('is-sliding');
                    slideTimer = setTimeout(() => {
                        currentIndex = idx;
                        renderCardAndLocale();
                        cardEl.classList.remove('is-sliding');
                        setTapState(true);
                        stepTimer = setTimeout(() => {
                            setTapState(false);
                            scheduleNextSlide();
                        }, 3400);
                    }, 220);
                } else {
                    cardEl.classList.remove('is-sliding');
                    setTapState(true);
                    stepTimer = setTimeout(() => {
                        setTapState(false);
                        scheduleNextSlide();
                    }, 3400);
                }
            });
        });

        const langObserver = new MutationObserver(() => {
            renderCardAndLocale();
        });
        langObserver.observe(document.documentElement, {
            attributes: true,
            attributeFilter: ['lang', 'dir']
        });

        renderCardAndLocale();
        if (!isPaused) {
            runCycle(1150);
        }
    }

    function initInteractiveCards() {
        const cards = Array.from(document.querySelectorAll('.step-card, .feat-card, .faq-item'));
        if (!cards.length) return;

        const hoverCapable = window.matchMedia('(hover: hover) and (pointer: fine)');
        const motionQuery = window.matchMedia('(prefers-reduced-motion: no-preference)');

        cards.forEach((card) => {
            let rafId = null;
            let lastEvent = null;

            const updateCardPointer = () => {
                rafId = null;
                if (!lastEvent || !hoverCapable.matches) return;
                const rect = card.getBoundingClientRect();
                if (!rect.width || !rect.height) return;

                const scaleX = card.offsetWidth ? (rect.width / card.offsetWidth) : 1;
                const scaleY = card.offsetHeight ? (rect.height / card.offsetHeight) : 1;
                const relX = (lastEvent.clientX - rect.left) / (scaleX || 1);
                const relY = (lastEvent.clientY - rect.top) / (scaleY || 1);
                card.style.setProperty('--mouse-x', `${relX.toFixed(1)}px`);
                card.style.setProperty('--mouse-y', `${relY.toFixed(1)}px`);

                if (motionQuery.matches) {
                    const normX = ((lastEvent.clientX - rect.left) / rect.width) - 0.5;
                    const normY = ((lastEvent.clientY - rect.top) / rect.height) - 0.5;
                    const tiltX = (-normY * 6.5).toFixed(2);
                    const tiltY = (normX * 6.5).toFixed(2);
                    card.style.setProperty('--tilt-x', `${tiltX}deg`);
                    card.style.setProperty('--tilt-y', `${tiltY}deg`);
                }
            };

            card.addEventListener('pointermove', (e) => {
                if (!hoverCapable.matches) return;
                lastEvent = e;
                if (!rafId) {
                    rafId = requestAnimationFrame(updateCardPointer);
                }
            });

            const resetTilt = () => {
                lastEvent = null;
                if (rafId) {
                    cancelAnimationFrame(rafId);
                    rafId = null;
                }
                card.style.setProperty('--tilt-x', '0deg');
                card.style.setProperty('--tilt-y', '0deg');
            };

            card.addEventListener('pointerleave', resetTilt);
            card.addEventListener('pointercancel', resetTilt);
        });

        // IntersectionObserver fallback only when native scroll-driven animations are unsupported
        const supportsScrollDriven = typeof CSS !== 'undefined' &&
            CSS.supports('(animation-timeline: view()) and (animation-range: entry)');
        if (!supportsScrollDriven && motionQuery.matches && 'IntersectionObserver' in window) {
            const revealTargets = Array.from(document.querySelectorAll('.section-header, .step-card, .feat-card, .faq-item, .app-footer'));
            const fallbackObserver = new IntersectionObserver((entries, obs) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        entry.target.classList.add('is-revealed');
                        obs.unobserve(entry.target);
                    }
                });
            }, {
                root: null,
                threshold: 0.08
            });
            revealTargets.forEach((el) => {
                el.classList.add('reveal-on-scroll');
                fallbackObserver.observe(el);
            });
        }
    }

    document.addEventListener('DOMContentLoaded', () => {
        initNavbarAndScrollTop();
        initLamsaShowcase();
        initInteractiveCards();
    });
})();
