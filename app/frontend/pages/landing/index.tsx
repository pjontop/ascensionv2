import { Form, Head } from "@inertiajs/react"
import posthog from "posthog-js"
import { toast } from "sonner"

import ascensionHero from "@/assets/illustrations/ascensionHero.png"
import heroInputScrollTexture from "@/assets/illustrations/heroInput-scrollTexture.svg"
import { Button } from "@/components/ui/button"
import { SpinnerCustom } from "@/components/ui/spinner"
import { loginPath } from "@/routes"

import "./landing.css"
import "./landing.desktop.css"
import "./landing.mobile.css"

export default function Landing() {
  return (
    <>
      <Head title="Ascension" />
      <main className="landing-page min-h-screen">
        <Button
          className="cta-secondary-button"
          variant="ctaSecondary"
          size="ctaSecondary"
          type="button"
          onClick={() => {
            posthog.capture("auth_login_clicked", { provider: "hackclub" })
            window.location.assign(loginPath())
          }}
        >
          login →
        </Button>
        <img
          className="landing-page__logo"
          src={ascensionHero}
          alt="Ascension"
          width={1048}
          height={313}
        />
        <h1 className="landing-page__headline">
          <span className="landing-page__headline-part">
            make projects <span aria-hidden="true">✦</span>{" "}
          </span>
          <span className="landing-page__headline-part-italic">
            get prizes.
          </span>
        </h1>
        <Form
          method="post"
          action="/rsvps"
          onBefore={(visit) => {
            const email = (visit.data as FormData).get?.("email") as
              | string
              | null
            posthog.capture("rsvp_form_submitted", { email })
            if (email) posthog.identify(email, { email })
          }}
          onError={(errors) => {
            const values = Object.values(errors)
              .flatMap((value) => (Array.isArray(value) ? value : [value]))
              .filter(Boolean)

            if (values.length === 0) {
              toast.error("Something went wrong. Please try again.")
              return
            }

            for (const message of new Set(values)) {
              toast.error(message)
            }
          }}
        >
          {({ errors, processing }) => (
            <>
              <div
                className="cta-email"
                role="group"
                aria-label="Email call to action"
              >
                <div className="cta-email__field-wrap">
                  <input
                    className="cta-email__input"
                    type="email"
                    name="email"
                    placeholder="Enter your email"
                    aria-label="Email"
                    required
                  />
                  <div className="cta-email__noise" aria-hidden="true" />
                </div>
                <img
                  className="cta-email__ornament cta-email__ornament--left"
                  src={heroInputScrollTexture}
                  alt=""
                  aria-hidden="true"
                  width={86}
                  height={40}
                />
                <img
                  className="cta-email__ornament cta-email__ornament--right"
                  src={heroInputScrollTexture}
                  alt=""
                  aria-hidden="true"
                  width={86}
                  height={40}
                />
              </div>
              {errors.email ? (
                <p className="mt-2 text-center text-sm text-white">
                  {errors.email}
                </p>
              ) : null}
              <div className="cta-button-anchor">
                <Button
                  className="cta-button"
                  variant="cta"
                  type="submit"
                  disabled={processing}
                >
                  {processing ? <SpinnerCustom /> : "Await your Ascension →"}
                </Button>
              </div>
            </>
          )}
        </Form>
        <div className="landing-page__color-overlay" aria-hidden="true" />
        <div className="landing-page__noise-overlay" aria-hidden="true" />
      </main>
    </>
  )
}
