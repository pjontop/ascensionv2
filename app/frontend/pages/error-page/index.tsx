import { Head } from "@inertiajs/react"

import config from "./error-config.json"
import "./error-page.css"

type ErrorEntry = {
  title: string
  description: string
  cta: string
}

function getEntry(status: number): ErrorEntry {
  const key = String(status) as keyof typeof config.errors
  return (
    config.errors[key] ?? {
      title: "Unexpected Error",
      description: "An unexpected error occurred.",
      cta: "Go Home →",
    }
  )
}

function statusClass(status: number) {
  if (status === 404) return "error-page--404"
  if (status === 422 || status === 400) return "error-page--422"
  if (status >= 500) return "error-page--500"
  return ""
}

/**
 * Splits a title so the last word is rendered italic and the rest upright.
 * Single-word titles are fully italic.
 */
function TitleText({ title }: { title: string }) {
  const lastSpace = title.lastIndexOf(" ")
  if (lastSpace === -1) {
    return <span className="error-page__title-italic">{title}</span>
  }
  return (
    <>
      <span className="error-page__title-regular">{title.slice(0, lastSpace + 1)}</span>
      <span className="error-page__title-italic">{title.slice(lastSpace + 1)}</span>
    </>
  )
}

export default function ErrorPage({ status }: { status: number }) {
  const { title, description, cta } = getEntry(status)

  return (
    <>
      <Head title={`${status} — ${title}`} />
      <main className={`error-page ${statusClass(status)}`}>
        <div className="error-page__content">
          <p className="error-page__code">{status}</p>
          <h1 className="error-page__title">
            <TitleText title={title} />
          </h1>
          <p className="error-page__description">{description}</p>
          <div className="error-page__cta">
            <a className="error-page__btn" href="/">
              {cta}
            </a>
          </div>
        </div>
        <div className="error-page__color-overlay" aria-hidden="true" />
        <div className="error-page__noise-overlay" aria-hidden="true" />
      </main>
    </>
  )
}
