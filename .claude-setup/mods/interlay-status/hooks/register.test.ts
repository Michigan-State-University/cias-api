import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { McpToolResult, On } from 'claude-code'

type PingAnswer = { value: McpToolResult } | { deny: string }
type Ping = () => Promise<PingAnswer>

const OK: McpToolResult = { content: [{ type: 'text', text: 'pong' }], isError: false }

const setup = (on: On, ping: Ping) => {
  const clock = mock.clock(on)
  const statuses: (string | undefined)[] = []
  const calls: { server: string; tool: string }[] = []

  on('ui.status', ($, e) => {
    statuses.push(e.text)
    return { value: undefined }
  })
  on('mcp.call', ($, e) => {
    calls.push({ server: e.server, tool: e.tool })
    return ping()
  })
  on('session.start', ($, e) => ({ cwd: e.cwd }))

  return { clock, statuses, calls }
}

const start = ($: Engine) =>
  $.session.start({ cwd: '/tmp', surface: 'terminal', isInteractive: true })

test('pings Interlay at start and shows connected', async ($, on) => {
  const { clock, statuses, calls } = setup(on, async () => ({ value: OK }))

  await start($)
  await clock.settle()

  expect(calls).toEqual([{ server: 'claude.ai Interlay', tool: 'ping' }])
  expect(statuses[0]).toBe('Interlay … checking')
  expect(statuses.at(-1)).toBe('Interlay ● connected · 0 ms')
})

test('shows disconnected with the reason when the call fails', async ($, on) => {
  const { clock, statuses } = setup(on, async () => ({ deny: 'server not connected' }))

  await start($)
  await clock.settle()

  expect(statuses.at(-1)).toMatch(/^Interlay ○ disconnected · .*server not connected/)
})

test('shows an error when ping answers isError', async ($, on) => {
  const { clock, statuses } = setup(on, async () => ({
    value: { content: [], isError: true },
  }))

  await start($)
  await clock.settle()

  expect(statuses.at(-1)).toBe('Interlay ⚠ ping returned an error')
})

test('times out a ping that never answers', async ($, on) => {
  const { clock, statuses } = setup(on, () => new Promise<PingAnswer>(() => {}))

  await start($)
  await clock.advance(10_000)

  expect(statuses.at(-1)).toBe('Interlay ○ disconnected · no answer in 10 s')
})

test('re-checks every minute and picks up a reconnect', async ($, on) => {
  let isUp = false
  const { clock, statuses, calls } = setup(on, async () =>
    isUp ? { value: OK } : { deny: 'needs auth' },
  )

  await start($)
  await clock.settle()
  expect(statuses.at(-1)).toMatch(/^Interlay ○ disconnected · .*needs auth/)

  isUp = true
  await clock.advance(60_000)

  expect(calls.length).toBe(2)
  expect(statuses.at(-1)).toBe('Interlay ● connected · 0 ms')
})
