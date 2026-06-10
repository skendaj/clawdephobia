import { Nav } from "@/components/nav";
import { Hero } from "@/components/hero";
// import { ProductCard } from "@/components/product-card";
import { FeatureGrid } from "@/components/feature-grid";
import { Walkthrough } from "@/components/walkthrough";
import { PowerFeatures } from "@/components/power-features";
import { CTA } from "@/components/cta";
import { Footer } from "@/components/footer";

export default function HomePage() {
  return (
    <main className="min-h-screen">
      <Nav />
      <Hero />
      {/* <ProductCard /> */}
      <FeatureGrid />
      <PowerFeatures />
      <Walkthrough />
      <CTA />
      <Footer />
    </main>
  );
}
