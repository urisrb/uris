import { Alert, Button, Group, Loader, Stack } from '@mantine/core'
import { SetSettingDocument, SettingsDocument } from '@uris-to/client'
import { useMutation, useQuery } from '@uris-to/client/react'

interface Props {
  who: string
  tenant?: string | null
  logout: () => void
  logoutEverywhere: () => void
}

export function Settings({ who, tenant, logout, logoutEverywhere }: Props) {
  const { data, loading, error, refetch } = useQuery(SettingsDocument)
  const save = useMutation(SetSettingDocument)

  const settings = data?.settings ?? []
  const stale = /does not carry settings:/.test(error?.message ?? '')

  return (
    <Stack gap="var(--s5)">
      <div>
        <h1 className="page-title">Settings</h1>
        <div className="eyebrow" style={{ marginTop: 'var(--s2)' }}>
          Who you are signed in as, and how items behaves for you
        </div>
      </div>

      {error &&
        (stale ? (
          <Alert
            color="yellow"
            title="This sign-in is older than these settings"
          >
            Your token was minted before items asked for the settings scopes, so
            it does not carry them. Sign out and back in and they will be there.
          </Alert>
        ) : (
          <Alert color="red">{error.message}</Alert>
        ))}

      <Stack gap="var(--s3)">
        <div className="label">Account</div>

        <div className="panel">
          <div className="setting">
            <div>
              <div className="setting-name">{who}</div>
              <div className="setting-note">
                {tenant
                  ? `Signed in to ${tenant}. Your sign-in lives in masks, not here.`
                  : 'Your sign-in lives in masks, not here.'}
              </div>
            </div>

            <Group gap="var(--s2)" wrap="nowrap">
              <Button size="xs" radius="xl" variant="default" onClick={logout}>
                Sign out
              </Button>
              <Button
                size="xs"
                radius="xl"
                variant="subtle"
                color="gray"
                onClick={logoutEverywhere}
              >
                Everywhere
              </Button>
            </Group>
          </div>
        </div>
      </Stack>

      <Stack gap="var(--s3)">
        <div className="label">Personal</div>

        {loading && !data && <Loader size="sm" color="var(--brass)" />}

        {settings.length > 0 && (
          <div className="panel">
            {settings.map((setting) => (
              <div className="setting" key={setting.key}>
                <div>
                  <div className="setting-name">{setting.label}</div>
                  {setting.note && (
                    <div className="setting-note">{setting.note}</div>
                  )}
                </div>

                <Choice
                  allowed={setting.allowed}
                  value={setting.value}
                  onPick={async (next) => {
                    await save.execute({ key: setting.key, value: next })
                    refetch()
                  }}
                />
              </div>
            ))}
          </div>
        )}
      </Stack>

      {save.error && <Alert color="red">{save.error.message}</Alert>}
    </Stack>
  )
}

function Choice({
  allowed,
  value,
  onPick,
}: {
  allowed: readonly string[]
  value: string
  onPick: (next: string) => void
}) {
  return (
    <div className="switcher" data-wide="true">
      {allowed.map((option) => (
        <button
          key={option}
          type="button"
          data-on={value === option}
          aria-pressed={value === option}
          onClick={() => onPick(option)}
        >
          {option}
        </button>
      ))}
    </div>
  )
}
