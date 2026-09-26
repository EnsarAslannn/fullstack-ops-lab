import './App.css'

function App() {
  return (
    <main className="page">
      <p className="eyebrow">Phase 0A · Application skeleton</p>
      <h1>FullStack Ops Lab</h1>
      <p>
        Sandbox Tasks will grow here. For now, the React frontend and .NET API
        run locally as separate applications.
      </p>
      <div className="links">
        <a href="http://localhost:5162/health">API health</a>
        <a href="http://localhost:5162/openapi/v1.json">OpenAPI document</a>
      </div>
    </main>
  )
}

export default App
