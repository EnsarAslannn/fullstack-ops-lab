export type TaskItem = {
  id: number
  title: string
  description: string | null
  isCompleted: boolean
  createdAt: string
  updatedAt: string
}

type CreateTask = {
  title: string
  description: string | null
}

type UpdateTask = CreateTask & {
  isCompleted: boolean
}

const tasksPath = '/api/tasks'

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  let response: Response

  try {
    response = await fetch(path, options)
  } catch (error) {
    if (options?.signal?.aborted) throw error
    throw new Error('API’ye bağlanılamadı. Backend uygulamasını başlatıp tekrar deneyin.')
  }

  if (!response.ok) {
    if (response.status === 400) {
      throw new Error('Görev bilgileri geçersiz. Başlığı kontrol edin.')
    }
    if (response.status === 404) {
      throw new Error('Görev bulunamadı. Listeyi yenileyin.')
    }
    if (response.status >= 500) {
      throw new Error('API’ye bağlanılamadı veya sunucu hata verdi. Backend uygulamasını kontrol edin.')
    }
    throw new Error(`İstek tamamlanamadı (HTTP ${response.status}). Tekrar deneyin.`)
  }

  if (response.status === 204) return undefined as T

  try {
    return (await response.json()) as T
  } catch {
    throw new Error('API beklenen yanıtı vermedi. Backend bağlantısını kontrol edin.')
  }
}

export function listTasks(signal?: AbortSignal): Promise<TaskItem[]> {
  return request<TaskItem[]>(tasksPath, { signal })
}

export function createTask(task: CreateTask): Promise<TaskItem> {
  return request<TaskItem>(tasksPath, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(task),
  })
}

export function updateTask(id: number, task: UpdateTask): Promise<TaskItem> {
  return request<TaskItem>(`${tasksPath}/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(task),
  })
}

export function deleteTask(id: number): Promise<void> {
  return request<void>(`${tasksPath}/${id}`, { method: 'DELETE' })
}
