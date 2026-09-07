import {
  type Dispatch,
  type SetStateAction,
  useEffect,
  useRef,
  useState,
} from 'react'

interface Paged<T> {
  nodes: readonly T[]
}

// Asking for the next page sets the cursor, but the answer arrives later and
// the query holds the page before it in the meantime. Reacting to the cursor
// alone would append the page already on screen a second time, so what has
// been taken is remembered and only a page that has not been is added.
export function usePages<T>(
  page: Paged<T> | null | undefined,
  cursor: string | null,
): [T[], Dispatch<SetStateAction<T[]>>] {
  const [rows, setRows] = useState<T[]>([])
  const taken = useRef<Paged<T> | null>(null)

  useEffect(() => {
    if (!page || page === taken.current) return

    taken.current = page
    setRows((held) => (cursor ? [...held, ...page.nodes] : [...page.nodes]))
  }, [page, cursor])

  return [rows, setRows]
}
