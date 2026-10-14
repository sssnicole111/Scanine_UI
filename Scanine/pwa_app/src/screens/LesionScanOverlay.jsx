import { useEffect, useRef, useState } from 'react'

export function extractCamRegions(heatmap, threshold = 0.45) {
  if (!heatmap) return []

  let gridH = 0
  let gridW = 0
  let getVal = (r, c) => 0

  if (Array.isArray(heatmap) && Array.isArray(heatmap[0])) {
    gridH = heatmap.length
    gridW = heatmap[0].length
    getVal = (r, c) => heatmap[r][c]
  } else if (heatmap.length) {
    if (heatmap.length === 49) {
      gridH = 7
      gridW = 7
    } else if (heatmap.length === 224 * 224) {
      gridH = 224
      gridW = 224
    } else {
      const dim = Math.round(Math.sqrt(heatmap.length))
      gridH = dim
      gridW = dim
    }
    getVal = (r, c) => heatmap[r * gridW + c]
  } else {
    return []
  }

  if (gridH <= 0 || gridW <= 0) return []

  const targetH = gridH > 14 ? 7 : gridH
  const targetW = gridW > 14 ? 7 : gridW

  const sampled = Array.from({ length: targetH }, (_, r) =>
    Array.from({ length: targetW }, (_, c) => {
      let maxVal = 0
      const rStep = Math.floor(gridH / targetH)
      const cStep = Math.floor(gridW / targetW)
      for (let dr = 0; dr < rStep; dr++) {
        for (let dc = 0; dc < cStep; dc++) {
          const v = getVal(r * rStep + dr, c * cStep + dc)
          if (v > maxVal) maxVal = v
        }
      }
      return maxVal
    })
  )

  let maxVal = 0
  for (let r = 0; r < targetH; r++) {
    for (let c = 0; c < targetW; c++) {
      if (sampled[r][c] > maxVal) maxVal = sampled[r][c]
    }
  }

  if (maxVal <= 0.001) return []

  const norm = Array.from({ length: targetH }, (_, r) =>
    Array.from({ length: targetW }, (_, c) => sampled[r][c] / maxVal)
  )

  const visited = Array.from({ length: targetH }, () => Array(targetW).fill(false))
  const regions = []

  for (let r = 0; r < targetH; r++) {
    for (let c = 0; c < targetW; c++) {
      if (visited[r][c] || norm[r][c] < threshold) continue

      let rowStart = r, rowEnd = r, colStart = c, colEnd = c
      let peak = norm[r][c]

      const queue = [[r, c]]
      visited[r][c] = true

      while (queue.length > 0) {
        const [cr, cc] = queue.shift()
        rowStart = Math.min(rowStart, cr)
        rowEnd = Math.max(rowEnd, cr)
        colStart = Math.min(colStart, cc)
        colEnd = Math.max(colEnd, cc)
        peak = Math.max(peak, norm[cr][cc])

        const neighbors = [[cr - 1, cc], [cr + 1, cc], [cr, cc - 1], [cr, cc + 1]]
        for (const [nr, nc] of neighbors) {
          if (nr >= 0 && nr < targetH && nc >= 0 && nc < targetW && !visited[nr][nc] && norm[nr][nc] >= threshold) {
            visited[nr][nc] = true
            queue.push([nr, nc])
          }
        }
      }

      const scanMid = (rowStart + rowEnd + 1) / (2 * targetH)
      regions.push({
        rowStart, rowEnd, colStart, colEnd,
        scanMid, peakActivation: peak,
        gridH: targetH, gridW: targetW
      })
    }
  }

  regions.sort((a, b) => a.scanMid - b.scanMid)
  return regions
}

const STATUS_MESSAGES = [
  'SCANNING SKIN SURFACE…',
  'IDENTIFYING AFFECTED AREAS…',
  'ANALYSING TEXTURE PATTERNS…',
  'MAPPING HIGH-ACTIVATION ZONES…',
  'FINALISING ASSESSMENT…'
]

const SWEEP_DURATION = 2800 // ms
const SETTLE_PAUSE = 600 // ms

export default function LesionScanOverlay({ imageSrc, heatmap, onFinished }) {
  const canvasRef = useRef(null)
  const containerRef = useRef(null)
  const [msgIdx, setMsgIdx] = useState(0)

  const regions = useRef([])
  try {
    regions.current = extractCamRegions(heatmap)
  } catch (err) {
    console.error('Region extraction error:', err)
    regions.current = []
  }

  useEffect(() => {
    const timer = setInterval(() => {
      setMsgIdx(prev => (prev < STATUS_MESSAGES.length - 1 ? prev + 1 : prev))
    }, 600)
    return () => clearInterval(timer)
  }, [])

  useEffect(() => {
    let animId
    let startTime = null
    const canvas = canvasRef.current
    const container = containerRef.current
    if (!canvas || !container) return

    const handleResize = () => {
      canvas.width = container.clientWidth
      canvas.height = container.clientHeight
    }
    handleResize()
    window.addEventListener('resize', handleResize)

    const ctx = canvas.getContext('2d')

    const render = (now) => {
      if (!startTime) startTime = now
      const elapsed = now - startTime
      const progress = Math.min(1.0, elapsed / SWEEP_DURATION)

      const easedT = progress < 0.5
        ? 2 * progress * progress
        : 1 - Math.pow(-2 * progress + 2, 2) / 2

      const w = canvas.width
      const h = canvas.height
      const pulseT = (now % 900) / 900

      ctx.clearRect(0, 0, w, h)

      // 1. Translucent Cyan Grid
      ctx.strokeStyle = 'rgba(0, 240, 255, 0.08)'
      ctx.lineWidth = 1
      const gridSize = 40
      ctx.beginPath()
      for (let x = 0; x <= w; x += gridSize) {
        ctx.moveTo(x, 0)
        ctx.lineTo(x, h)
      }
      for (let y = 0; y <= h; y += gridSize) {
        ctx.moveTo(0, y)
        ctx.lineTo(w, y)
      }
      ctx.stroke()

      // 2. Corner HUD Brackets
      const pad = 16
      const len = 16
      ctx.strokeStyle = 'rgba(0, 240, 255, 0.5)'
      ctx.lineWidth = 1.5
      ctx.beginPath()
      ctx.moveTo(pad, pad + len); ctx.lineTo(pad, pad); ctx.lineTo(pad + len, pad)
      ctx.moveTo(w - pad - len, pad); ctx.lineTo(w - pad, pad); ctx.lineTo(w - pad, pad + len)
      ctx.moveTo(pad, h - pad - len); ctx.lineTo(pad, h - pad); ctx.lineTo(pad + len, h - pad)
      ctx.moveTo(w - pad - len, h - pad); ctx.lineTo(w - pad, h - pad); ctx.lineTo(w - pad, h - pad - len)
      ctx.stroke()

      // 3. Circular Progress Ring Badge (Top Right)
      const cxBadge = w - 50
      const cyBadge = 65
      const rBadge = 22

      ctx.fillStyle = 'rgba(7, 17, 36, 0.85)'
      ctx.beginPath()
      ctx.arc(cxBadge, cyBadge, rBadge, 0, Math.PI * 2)
      ctx.fill()

      ctx.strokeStyle = 'rgba(0, 240, 255, 0.2)'
      ctx.lineWidth = 2
      ctx.stroke()

      ctx.strokeStyle = '#00F0FF'
      ctx.lineWidth = 2.5
      ctx.lineCap = 'round'
      ctx.beginPath()
      ctx.arc(cxBadge, cyBadge, rBadge, -Math.PI / 2, -Math.PI / 2 + progress * Math.PI * 2)
      ctx.stroke()

      ctx.fillStyle = '#00F0FF'
      ctx.font = 'bold 10px monospace'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText(`${Math.round(progress * 100)}%`, cxBadge, cyBadge)

      // 4. Discovered Regions
      const lineY = easedT * h

      if (regions.current && regions.current.length > 0) {
        regions.current.forEach((r, idx) => {
          if (easedT >= r.scanMid) {
            const pl = (r.colStart / r.gridW) * w
            const pr = ((r.colEnd + 1) / r.gridW) * w
            const pt = (r.rowStart / r.gridH) * h
            const pb = ((r.rowEnd + 1) / r.gridH) * h

            const rw = pr - pl
            const rh = pb - pt
            const rcx = (pl + pr) / 2
            const rcy = (pt + pb) / 2

            const pulseFactor = Math.sin(pulseT * Math.PI)
            const intensity = 0.65 + 0.35 * r.peakActivation

            ctx.fillStyle = `rgba(0, 240, 255, ${(0.08 + 0.12 * pulseFactor) * intensity})`
            ctx.fillRect(pl, pt, rw, rh)

            ctx.strokeStyle = `rgba(0, 240, 255, ${(0.75 + 0.25 * pulseFactor) * intensity})`
            ctx.lineWidth = 2
            ctx.strokeRect(pl, pt, rw, rh)

            const nodeRadius = 5 + 2.5 * pulseFactor
            ctx.strokeStyle = 'rgba(0, 240, 255, 0.5)'
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.arc(rcx, rcy, nodeRadius + 4, 0, Math.PI * 2)
            ctx.stroke()

            ctx.fillStyle = '#00F0FF'
            ctx.beginPath()
            ctx.arc(rcx, rcy, nodeRadius, 0, Math.PI * 2)
            ctx.fill()

            ctx.fillStyle = '#FFFFFF'
            ctx.beginPath()
            ctx.arc(rcx, rcy, 2, 0, Math.PI * 2)
            ctx.fill()

            const isRightSide = rcx < w * 0.6
            const leaderX1 = isRightSide ? rcx + 25 : rcx - 25
            const leaderX2 = isRightSide ? leaderX1 + 25 : leaderX1 - 25
            const leaderY2 = rcy - 18

            ctx.strokeStyle = 'rgba(0, 240, 255, 0.8)'
            ctx.lineWidth = 1.2
            ctx.beginPath()
            ctx.moveTo(rcx, rcy)
            ctx.lineTo(leaderX1, rcy)
            ctx.lineTo(leaderX2, leaderY2)
            ctx.stroke()

            ctx.fillStyle = '#00F0FF'
            ctx.beginPath()
            ctx.arc(leaderX2, leaderY2, 2.5, 0, Math.PI * 2)
            ctx.fill()

            const tagText = `REGION 0${idx + 1} // HUD_ACTIVE`
            ctx.font = 'bold 9px monospace'
            const tagMetrics = ctx.measureText(tagText)
            const tagW = tagMetrics.width + 12
            const tagH = 16
            const tagLeft = isRightSide ? leaderX2 + 4 : leaderX2 - tagW - 4
            const tagTop = leaderY2 - tagH / 2

            ctx.fillStyle = 'rgba(7, 17, 36, 0.9)'
            ctx.fillRect(tagLeft, tagTop, tagW, tagH)
            ctx.strokeStyle = 'rgba(0, 240, 255, 0.5)'
            ctx.lineWidth = 0.8
            ctx.strokeRect(tagLeft, tagTop, tagW, tagH)

            ctx.fillStyle = '#00F0FF'
            ctx.textAlign = 'left'
            ctx.textBaseline = 'middle'
            ctx.fillText(tagText, tagLeft + 6, tagTop + tagH / 2)
          }
        })
      }

      // 5. Eased Cyan Scan Line Slit & Gradient Wake
      if (progress > 0 && progress < 1) {
        const wakeH = 80
        const wakeTop = Math.max(0, lineY - wakeH)

        const wakeGrad = ctx.createLinearGradient(0, wakeTop, 0, lineY)
        wakeGrad.addColorStop(0, 'rgba(0, 168, 255, 0)')
        wakeGrad.addColorStop(1, 'rgba(0, 168, 255, 0.28)')
        ctx.fillStyle = wakeGrad
        ctx.fillRect(0, wakeTop, w, lineY - wakeTop)

        const slitH = 3
        const lineGrad = ctx.createLinearGradient(0, lineY - slitH / 2, 0, lineY + slitH / 2)
        lineGrad.addColorStop(0, 'rgba(0, 240, 255, 0)')
        lineGrad.addColorStop(0.3, 'rgba(0, 240, 255, 0.95)')
        lineGrad.addColorStop(0.5, 'rgba(255, 255, 255, 1.0)')
        lineGrad.addColorStop(0.7, 'rgba(0, 240, 255, 0.95)')
        lineGrad.addColorStop(1, 'rgba(0, 240, 255, 0)')
        ctx.fillStyle = lineGrad
        ctx.fillRect(0, lineY - slitH / 2, w, slitH)
      }

      if (progress < 1.0) {
        animId = requestAnimationFrame(render)
      } else {
        setTimeout(() => {
          if (onFinished) onFinished()
        }, SETTLE_PAUSE)
      }
    }

    animId = requestAnimationFrame(render)

    return () => {
      cancelAnimationFrame(animId)
      window.removeEventListener('resize', handleResize)
    }
  }, [heatmap, onFinished])

  return (
    <div ref={containerRef} className="lesion-scan-container">
      {imageSrc && (
        <img src={imageSrc} alt="Scanning target" className="lesion-scan-image" />
      )}
      <div className="lesion-scan-backdrop" />
      <canvas ref={canvasRef} className="lesion-scan-canvas" />

      <div className="hud-disclaimer-badge">
        <span className="hud-dot" />
        <span>SCREENING AID — NOT A DIAGNOSIS</span>
      </div>

      <div className="hud-bottom-bar">
        <div className="hud-status-text">{STATUS_MESSAGES[msgIdx]}</div>
        <div className="hud-progress-track">
          <div className="hud-progress-fill" />
        </div>
      </div>
    </div>
  )
}
