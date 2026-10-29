import './HomeScreen.css'

export default function HomeScreen({ onStart }) {
  return (
    <main className="home">
      <header className="top rise" style={{ '--d': 0.05 }}>
        <div className="mark">scanine</div>
        <span className="status">
          <span className="dot" />
          works offline
        </span>
      </header>

      <div className="spacer" />

      <h1 className="headline rise" style={{ '--d': 0.2 }}>
        screen in<br />five frames<em>.</em>
      </h1>
      <p className="sub rise" style={{ '--d': 0.32 }}>
        Point the camera at the affected area to begin.
      </p>

      <div className="frames rise" style={{ '--d': 0.42 }} aria-hidden="true">
        <i /><i /><i /><i /><i />
      </div>

      <button
        className="cta rise"
        style={{ '--d': 0.5 }}
        onClick={onStart}
        aria-label="start screening"
      >
        start screening
        <span className="cam">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z" />
            <circle cx="12" cy="13" r="4" />
          </svg>
        </span>
      </button>
    </main>
  )
}
