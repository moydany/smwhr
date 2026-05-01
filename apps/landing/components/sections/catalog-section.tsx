import { CategoryCard } from "@/components/shared/category-card";
import { COPY } from "@/lib/copy";

export function CatalogSection() {
  return (
    <section className="snap-section relative flex min-h-screen items-center px-6 py-24 sm:px-12">
      <div className="mx-auto w-full max-w-6xl">
        <h2 className="max-w-3xl font-display font-medium leading-[1.05] text-text-primary text-4xl sm:text-5xl lg:text-[64px]">
          {COPY.catalog.headline1}
          <br />
          {COPY.catalog.headline2}
          <br />
          {COPY.catalog.headline3}
        </h2>

        <div className="mt-16 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {COPY.catalog.categories.map((cat) => (
            <CategoryCard
              key={cat.title}
              title={cat.title}
              subtitle={cat.subtitle}
              color={cat.color}
            />
          ))}
        </div>

        <p className="mx-auto mt-16 max-w-2xl text-center font-body text-base leading-relaxed text-text-secondary sm:text-[17px]">
          {COPY.catalog.description}
        </p>
      </div>
    </section>
  );
}
