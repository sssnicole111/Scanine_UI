import { useState } from 'react'
import './ResultScreen.css'

const URGENCY_TEXT = {
  high: 'Urgent — refer to a veterinarian',
  medium: 'Veterinary consultation recommended',
  low: 'No action required'
}

export default function ResultScreen({ result, onScanAgain, onHome }) {
  const [view, setView] = useState('photo') // 'photo' | 'heatmap'
  const [showProgress, setShowProgress] = useState(false)

  if (!result) return null

  // Inconclusive (confidence-abstention gate) and invalid-subject outcomes
  // both route to the same reassuring "we couldn't tell" screen.
  if (result.outcome !== 'classified') {
    return <InconclusiveScreen result={result} onScanAgain={onScanAgain} onHome={onHome} />
  }

  const confidence = Math.round((result.confidence || 0) * 100)
  const hasHeatmap = Boolean(result.heatmapImage)
  const showHeatmap = view === 'heatmap' && hasHeatmap

  return (
    <div className="result-screen">
      <div className="result-top-bar">
        <button className="icon-btn-ghost" onClick={onHome} aria-label="Back to home">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="15 18 9 12 15 6"></polyline>
          </svg>
        </button>
        <div className="result-meta">
          <span className="result-timestamp">
            Today · {new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
          </span>
          <button
            className="progress-badge"
            onClick={() => setShowProgress(true)}
            aria-label="Two conditions are still in development"
            title="Two conditions are still in development"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="10"></circle>
              <line x1="12" y1="7.5" x2="12" y2="13"></line>
              <line x1="12" y1="16.6" x2="12.01" y2="16.6"></line>
            </svg>
          </button>
        </div>
      </div>

      <div className="result-body">
        <div className="hero-card">
          <img
            src={showHeatmap ? result.heatmapImage : result.rawImage}
            alt={showHeatmap ? 'Grad-CAM heatmap' : 'Captured photo'}
            className="hero-img"
          />

          {hasHeatmap && (
            <div className="hero-toggle">
              <button className={view === 'photo' ? 'active' : ''} onClick={() => setView('photo')}>Photo</button>
              <button className={view === 'heatmap' ? 'active' : ''} onClick={() => setView('heatmap')}>Heatmap</button>
            </div>
          )}

          <span className="hero-confidence-pill">{confidence}%</span>

          <div className="hero-scrim">
            <h1 className="hero-condition">{result.condition}</h1>
            <p className="hero-condition-sub">{result.conditionLabel}</p>
          </div>
        </div>

        {showHeatmap && (
          <p className="heatmap-caption">
            Grad-CAM overlay — a coarse indicator of model attention, not a lesion boundary.
          </p>
        )}

        <p className="vote-line">
          <span className="vote-dot" />
          {result.agreeVotes}/{result.totalFrames} frames agreed on {result.condition}
        </p>

        <div className="guidance-card">
          <span className="guidance-title">First-response guidance</span>
          <ul className="guidance-list">
            {(result.guidance || []).map((line) => (
              <li key={line}>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                  <polyline points="20 6 9 17 4 12"></polyline>
                </svg>
                <span>{line}</span>
              </li>
            ))}
          </ul>
        </div>

        <div className="result-disclaimer">
          Scanine is a triage aid only. Not a veterinary diagnosis.
        </div>
      </div>

      <div className="result-cta">
        <button className={`btn-referral ${result.urgency}`} onClick={onScanAgain} title={URGENCY_TEXT[result.urgency]}>
          {result.referralText}
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="5" y1="12" x2="19" y2="12"></line>
            <polyline points="12 5 19 12 12 19"></polyline>
          </svg>
        </button>
      </div>

      {showProgress && (
        <div className="progress-sheet-scrim" onClick={() => setShowProgress(false)}>
          <div
            className="progress-sheet"
            role="dialog"
            aria-modal="true"
            aria-labelledby="progress-sheet-title"
            onClick={(e) => e.stopPropagation()}
          >
            <span className="progress-sheet-grip" aria-hidden="true" />
            <h2 className="progress-sheet-title" id="progress-sheet-title">In development</h2>
            <p className="progress-sheet-lead">
              Scanine currently reports ringworm and dermatologically normal skin.
              Two conditions from the full model are still being trained:
            </p>

            <ul className="progress-list">
              <li>
                <span className="progress-list-name">Flea Allergy Dermatitis</span>
                <span className="progress-list-sub">FAD — itch and hair loss from flea bite hypersensitivity</span>
              </li>
              <li>
                <span className="progress-list-name">Hotspot</span>
                <span className="progress-list-sub">Acute moist dermatitis</span>
              </li>
            </ul>

            <p className="progress-sheet-note">
              A case showing either condition may come back inconclusive until these classes ship.
            </p>

            <button className="progress-sheet-close" onClick={() => setShowProgress(false)}>
              Got it
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

function InconclusiveScreen({ result, onScanAgain, onHome }) {
  const isInvalid = result?.outcome === 'invalid'
  const heading = isInvalid ? 'No dog detected' : 'Inconclusive result'
  const message = result?.message ||
    "The model wasn't confident enough to assign a category. This can happen when a presentation falls outside Scanine's three trained conditions — such as mange or pyoderma."

  return (
    <div className="inconclusive-screen">
      <div className="inconclusive-body">
        <div className="inconclusive-icon">
          <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="10"></circle>
            <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"></path>
            <line x1="12" y1="17" x2="12.01" y2="17"></line>
          </svg>
        </div>
        <h1 className="inconclusive-title">{heading}</h1>
        <p className="inconclusive-desc">{message}</p>
      </div>

      <div className="inconclusive-actions">
        {!isInvalid && (
          <button className="btn-consult" onClick={onHome}>Consult a veterinarian</button>
        )}
        <button className="btn-rescan" onClick={onScanAgain}>Rescan this animal</button>
      </div>
    </div>
  )
}
