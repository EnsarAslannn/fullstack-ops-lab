import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { createTask, deleteTask, listTasks, updateTask } from './api/tasks'
import type { TaskItem } from './api/tasks'
import './App.css'

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Beklenmeyen bir hata oluştu. Tekrar deneyin.'
}

function App() {
  const [tasks, setTasks] = useState<TaskItem[]>([])
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [titleError, setTitleError] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [hasLoaded, setHasLoaded] = useState(false)
  const [pendingAction, setPendingAction] = useState<string | null>(null)
  const [reloadKey, setReloadKey] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    listTasks(controller.signal)
      .then((loadedTasks) => {
        if (controller.signal.aborted) return
        setTasks(loadedTasks)
        setHasLoaded(true)
        setError(null)
      })
      .catch((cause) => {
        if (!controller.signal.aborted) setError(errorMessage(cause))
      })
      .finally(() => {
        if (!controller.signal.aborted) setIsLoading(false)
      })
    return () => controller.abort()
  }, [reloadKey])

  const canInteract = hasLoaded && !isLoading && pendingAction === null
  const completedCount = tasks.filter((task) => task.isCompleted).length

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!canInteract) return

    const trimmedTitle = title.trim()
    if (!trimmedTitle) {
      setTitleError('Başlık boş olamaz.')
      return
    }

    setTitleError(null)
    setError(null)
    setPendingAction('create')

    try {
      const createdTask = await createTask({
        title: trimmedTitle,
        description: description.trim() || null,
      })
      setTasks((current) => [...current, createdTask])
      setTitle('')
      setDescription('')
    } catch (cause) {
      setError(errorMessage(cause))
    } finally {
      setPendingAction(null)
    }
  }

  async function handleToggle(task: TaskItem) {
    if (!canInteract) return
    setError(null)
    setPendingAction(`update:${task.id}`)

    try {
      const updatedTask = await updateTask(task.id, {
        title: task.title,
        description: task.description,
        isCompleted: !task.isCompleted,
      })
      setTasks((current) => current.map((item) => item.id === task.id ? updatedTask : item))
    } catch (cause) {
      setError(errorMessage(cause))
    } finally {
      setPendingAction(null)
    }
  }

  async function handleDelete(id: number) {
    if (!canInteract) return
    setError(null)
    setPendingAction(`delete:${id}`)

    try {
      await deleteTask(id)
      setTasks((current) => current.filter((task) => task.id !== id))
    } catch (cause) {
      setError(errorMessage(cause))
    } finally {
      setPendingAction(null)
    }
  }

  return (
    <main className="page">
      <header className="intro">
        <p className="eyebrow">FullStack Ops Lab / Phase 0C</p>
        <h1>Sandbox Tasks</h1>
        <p className="intro-copy">
          Görevlerini ekle, tamamla ve sil. API yeniden başladığında bu oturumdaki
          görevler silinir.
        </p>
      </header>

      <div className="summary" aria-live="polite">
        <span><strong>{tasks.length}</strong> görev</span>
        <span><strong>{completedCount}</strong> tamamlandı</span>
        <span className="memory-note">Bellekte saklanır</span>
      </div>

      {error && (
        <div className="notice" role="alert">
          <p>{error}</p>
          <button
            type="button"
            onClick={() => {
              setIsLoading(true)
              setError(null)
              setReloadKey((current) => current + 1)
            }}
            disabled={isLoading || pendingAction !== null}
          >
            Listeyi yenile
          </button>
        </div>
      )}

      <div className="workspace">
        <section className="panel create-panel" aria-labelledby="create-heading">
          <h2 id="create-heading">Yeni görev</h2>
          <p className="panel-hint">Yapılacak işi kısa bir başlıkla kaydet.</p>
          <form aria-label="Yeni görev" onSubmit={handleCreate} noValidate>
            <label htmlFor="task-title">Başlık</label>
            <input
              id="task-title"
              value={title}
              onChange={(event) => {
                setTitle(event.target.value)
                if (titleError) setTitleError(null)
              }}
              disabled={!canInteract}
              aria-invalid={Boolean(titleError)}
              aria-describedby={titleError ? 'title-error' : undefined}
              placeholder="Örn. API akışını doğrula"
            />
            {titleError && <p id="title-error" className="field-error" role="alert">{titleError}</p>}

            <label htmlFor="task-description">Açıklama</label>
            <textarea
              id="task-description"
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              disabled={!canInteract}
              placeholder="İsteğe bağlı ayrıntı"
              rows={3}
            />

            <button className="primary-button" type="submit" disabled={!canInteract}>
              {pendingAction === 'create' ? 'Ekleniyor...' : 'Görev ekle'}
            </button>
          </form>
        </section>

        <section className="panel tasks-panel" aria-labelledby="tasks-heading">
          <div className="panel-heading">
            <div>
              <h2 id="tasks-heading">Görevler</h2>
              <p className="panel-hint">Bu oturumdaki görevlerin.</p>
            </div>
          </div>

          {isLoading && <p className="state-message" role="status">Görevler yükleniyor...</p>}
          {!isLoading && hasLoaded && tasks.length === 0 && (
            <div className="empty-state">
              <p>Henüz görev yok.</p>
              <span>İlk görevini yeni görev formundan ekleyebilirsin.</span>
            </div>
          )}
          {tasks.length > 0 && (
            <ul className="task-list">
              {tasks.map((task) => (
                <li className={`task${task.isCompleted ? ' is-complete' : ''}`} key={task.id}>
                  <div className="task-details">
                    <span className="task-status">{task.isCompleted ? 'Tamamlandı' : 'Açık'}</span>
                    <h3>{task.title}</h3>
                    {task.description && <p>{task.description}</p>}
                  </div>
                  <div className="task-actions">
                    <button type="button" onClick={() => void handleToggle(task)} disabled={!canInteract}>
                      {pendingAction === `update:${task.id}` ? 'Kaydediliyor...' : task.isCompleted ? 'Yeniden aç' : 'Tamamla'}
                    </button>
                    <button className="delete-button" type="button" onClick={() => void handleDelete(task.id)} disabled={!canInteract}>
                      {pendingAction === `delete:${task.id}` ? 'Siliniyor...' : 'Sil'}
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </main>
  )
}

export default App
