import { Nav } from "@/components/sections/nav";
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
import { Footer } from "@/components/sections/footer";

export default function Home() {
  return (
    <>
      <Nav />
      <Hero />
      <Stats />
      <How />
      <Split />
      <Surfaces />
      <Insights />
      <Dashboard />
      <Limits />
      <ShareCard />
      <Social />
      <Pricing />
      <Faq />
      <Privacy />
      <Cta />
      <Footer />
    </>
  );
}
