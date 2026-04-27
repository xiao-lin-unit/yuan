/**
 * Auto Task Runner
 * 自动任务执行器
 *
 * Usage:
 *   1. Create a task file in src/auto/tasks/
 *   2. Call registerTask(name, asyncFn) to register
 *   3. Import the task file in src/auto/tasks/index.ts
 *   4. On app startup, runAutoTasks() will execute all registered tasks
 */

export interface AutoTask {
  name: string
  run: () => Promise<void>
}

const tasks: AutoTask[] = []

/**
 * Register an auto task
 * @param name Task name (for logging)
 * @param run Async function to execute
 */
export function registerTask(name: string, run: () => Promise<void>) {
  tasks.push({ name, run })
}

/**
 * Run all registered auto tasks sequentially
 * Errors in individual tasks are caught and logged, not thrown
 */
export async function runAutoTasks() {
  if (tasks.length === 0) {
    return
  }

  for (const task of tasks) {
    try {
      await task.run()
    } catch (error) {
    }
  }

}

/**
 * Get list of registered task names (for debugging)
 */
export function getRegisteredTaskNames(): string[] {
  return tasks.map((t) => t.name)
}
