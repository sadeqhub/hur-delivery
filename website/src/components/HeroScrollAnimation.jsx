import { useEffect, useRef, useState } from 'react';
import '../styles/HeroScrollAnimation.css';

const FRAME_COUNT = 240;
const FRAME_PATH = (i) => `/hero-frames/frame-${String(i).padStart(3, '0')}.webp`;

const HeroScrollAnimation = () => {
  const containerRef = useRef(null);
  const canvasRef = useRef(null);
  const framesRef = useRef([]);
  const currentFrameRef = useRef(0);
  const rafRef = useRef(null);
  const [, setLoaded] = useState(0);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const images = new Array(FRAME_COUNT);
    let count = 0;

    const onOne = () => {
      if (cancelled) return;
      count += 1;
      setLoaded(count);
      if (count === 1) setReady(true);
    };

    for (let i = 0; i < FRAME_COUNT; i++) {
      const img = new Image();
      img.decoding = 'async';
      img.loading = 'eager';
      img.src = FRAME_PATH(i + 1);
      img.onload = onOne;
      img.onerror = onOne;
      images[i] = img;
    }
    framesRef.current = images;

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container) return;
    const ctx = canvas.getContext('2d');

    const drawFrame = (index) => {
      const img = framesRef.current[index];
      if (!img || !img.complete || img.naturalWidth === 0) return;
      const rect = canvas.getBoundingClientRect();
      const cw = rect.width;
      const ch = rect.height;
      ctx.clearRect(0, 0, cw, ch);
      // contain-fit
      const ir = img.naturalWidth / img.naturalHeight;
      const cr = cw / ch;
      let dw, dh, dx, dy;
      if (ir > cr) {
        dw = cw;
        dh = cw / ir;
        dx = 0;
        dy = (ch - dh) / 2;
      } else {
        dh = ch;
        dw = ch * ir;
        dx = (cw - dw) / 2;
        dy = 0;
      }
      ctx.drawImage(img, dx, dy, dw, dh);
    };

    const sizeCanvas = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const rect = canvas.getBoundingClientRect();
      canvas.width = Math.round(rect.width * dpr);
      canvas.height = Math.round(rect.height * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      drawFrame(currentFrameRef.current);
    };

    const onScroll = () => {
      if (rafRef.current) return;
      rafRef.current = requestAnimationFrame(() => {
        rafRef.current = null;
        const rect = container.getBoundingClientRect();
        const vh = window.innerHeight;
        const total = container.offsetHeight - vh;
        const scrolled = Math.min(Math.max(-rect.top, 0), total);
        const progress = total > 0 ? scrolled / total : 0;
        const frame = Math.min(
          FRAME_COUNT - 1,
          Math.max(0, Math.round(progress * (FRAME_COUNT - 1)))
        );
        if (frame !== currentFrameRef.current) {
          currentFrameRef.current = frame;
          drawFrame(frame);
        }
      });
    };

    sizeCanvas();
    drawFrame(0);
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', sizeCanvas);
    onScroll();

    // Re-paint as more frames stream in (in case the current scroll
    // position lands on a frame that hadn't loaded yet).
    const repaintInterval = setInterval(() => drawFrame(currentFrameRef.current), 200);

    return () => {
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', sizeCanvas);
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      clearInterval(repaintInterval);
    };
  }, [ready]);

  return (
    <section ref={containerRef} className="hero-scroll-animation" aria-hidden="true">
      <div className="hero-scroll-stage">
        <canvas ref={canvasRef} className="hero-scroll-canvas" />
      </div>
    </section>
  );
};

export default HeroScrollAnimation;
