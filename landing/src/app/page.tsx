import { SiteNav } from "@/components/site-nav";
import { SiteFooter } from "@/components/site-footer";
import { Hero } from "@/components/sections/hero";
import { Stats } from "@/components/sections/stats";
import { How } from "@/components/sections/how";
import { Split } from "@/components/sections/split";
import { Surfaces } from "@/components/sections/surfaces";
import { Insights } from "@/components/sections/insights";
import { Dashboard } from "@/components/sections/dashboard";
import { Limits } from "@/components/sections/limits";
import { ShareCard } from "@/components/sections/sharecard";
import { Social } from "@/components/sections/social";
import { Pricing } from "@/components/sections/pricing";
import { Faq } from "@/components/sections/faq";
import { Privacy } from "@/components/sections/privacy";
import { Cta } from "@/components/sections/cta";

export default function Home() {
  return (
    <>
      <SiteNav />
      <Hero />
      <Stats />
      <How />
      <Split />
      <Limits />
      <Surfaces />
      <Insights />
      <Dashboard />
      <ShareCard />
      <Social />
      <Pricing />
      <Faq />
      <Privacy />
      <Cta />
      <SiteFooter />
    </>
  );
}
