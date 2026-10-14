import { useState } from 'react'
import ScanineSplash from './screens/ScanineSplash'
import HomeScreen from './screens/HomeScreen'
import CameraScreen from './screens/CameraScreen'
import ResultScreen from './screens/ResultScreen'
import './App.css'

export default function App() {
  const [screen, setScreen] = useState('splash')
  const [result, setResult] = useState(null)

  const goTo = (screenName, data = null) => {
    if (data) setResult(data)
    setScreen(screenName)
  }

  return (
    <div className="app-root">
      {screen === 'splash' && (
        <ScanineSplash onFinished={() => goTo('home')} />
      )}
      {screen === 'home' && (
        <HomeScreen onStart={() => goTo('camera')} />
      )}
      {screen === 'camera' && (
        <CameraScreen
          onResult={(data) => goTo('result', data)}
          onBack={() => goTo('home')}
        />
      )}
      {screen === 'result' && (
        <ResultScreen
          result={result}
          onScanAgain={() => goTo('camera')}
          onHome={() => goTo('home')}
        />
      )}
    </div>
  )
}