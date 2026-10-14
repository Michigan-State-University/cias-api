import type { Register, Timer } from 'claude-code'

const SERVER = 'claude.ai Interlay'
const POLL_MS = 60_000
const TIMEOUT_MS = 10_000

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    let isChecking = false

    const check = async () => {
      if (isChecking) return
      isChecking = true
      let timer: Timer | undefined
      const startedAt = await $.clock.now()

      try {
        const timedOut = new Promise<never>((_, reject) => {
          timer = $.clock.after(TIMEOUT_MS, () =>
            reject(new Error(`no answer in ${TIMEOUT_MS / 1000} s`)),
          )
        })
        const result = await Promise.race([$.mcp.call(SERVER, 'ping'), timedOut])
        const elapsedMs = (await $.clock.now()) - startedAt

        $.ui.status(
          result.isError
            ? 'Interlay ⚠ ping returned an error'
            : `Interlay ● connected · ${elapsedMs} ms`,
        )
      } catch (error) {
        const reason = error instanceof Error ? error.message : String(error)
        $.ui.status(`Interlay ○ disconnected · ${reason.slice(0, 60)}`)
      } finally {
        timer?.cancel()
        isChecking = false
      }
    }

    $.ui.status('Interlay … checking')
    void check()
    $.clock.every(POLL_MS, () => void check())

    return next(e)
  })
}
