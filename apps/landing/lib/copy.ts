export const COPY = {
  hero: {
    coordinates: "20.0850° N · -98.3630° W",
    headline1: "Estuviste ahí.",
    headline2: "Tenemos la prueba.",
    subtitle:
      "Una app que verifica tu asistencia a eventos en vivo y la convierte en una colección que es tuya.",
    cta: "Apúntate a la lista",
    counter: (n: number) => `${n} personas ya están dentro`,
    scrollHint: "Mira cómo funciona",
  },
  proof: {
    headline: "No es un check-in. Es prueba.",
    description:
      "GPS · Tiempo de permanencia · Integridad del dispositivo. Tres capas que aseguran que sí estuviste ahí.",
    chips: [
      { label: "Ubicación", icon: "map-pin" as const },
      { label: "Tiempo", icon: "timer" as const },
      { label: "Integridad", icon: "shield-check" as const },
    ],
  },
  how: {
    headline: "Tres pasos. Una historia.",
    steps: [
      {
        number: "01",
        title: "Llegas",
        description:
          "Marcas el evento. Llegamos cuando tú llegas. La app detecta el venue por GPS y activa la quest sola.",
      },
      {
        number: "02",
        title: "Te quedas",
        description:
          "60 minutos mínimo. Si te vas antes, no cuenta. Si te quedas, capturas un momento con la cámara que la app provee, no la galería.",
      },
      {
        number: "03",
        title: "Recibes",
        description:
          "Al terminar, tu insignia se genera con número de serie único. Se guarda en tu colección. Es tuya.",
      },
    ],
  },
  catalog: {
    headline1: "Toda la noche.",
    headline2: "Todos los partidos.",
    headline3: "Todas las cumbres.",
    categories: [
      { title: "Conciertos", subtitle: "Estadios y foros", color: "#FF2D95" },
      { title: "Partidos", subtitle: "Liga, copa, mundial", color: "#2DFF95" },
      { title: "Festivales", subtitle: "Multi-día", color: "#FF9D2D" },
      { title: "Outdoor", subtitle: "Cumbres y trails", color: "#2DC8FF" },
      { title: "Cultura", subtitle: "Teatro y arte", color: "#9D2DFF" },
      { title: "Lo que venga", subtitle: "Tu evento", color: "gradient" },
    ],
    description:
      "Cada categoría tiene su marco, su color, su lenguaje visual. Las insignias se sienten distintas porque la experiencia lo es.",
  },
  finalCta: {
    headline: "Vamos a empezar.",
    cta: "Apúntate a la lista",
  },
  footer: {
    location: "Hecho en MX · 2026",
    studio: "Una venture de Orbit M",
    twitter: { handle: "@smwhr", url: "https://x.com/smwhr" },
    instagram: { handle: "@smwhr.quest", url: "https://instagram.com/smwhr.quest" },
  },
  modal: {
    title: "Bienvenido a smwhr.",
    subtitle: "Te avisamos cuando estemos listos. Sin spam.",
    emailPlaceholder: "tu@correo.com",
    interestsLabel: "¿Qué eventos te mueven?",
    interests: [
      { value: "music", label: "Música" },
      { value: "sports", label: "Deportes" },
      { value: "festivals", label: "Festivales" },
      { value: "outdoor", label: "Outdoor" },
      { value: "all", label: "Todo" },
    ],
    submit: "Apúntame",
    submitting: "Apuntándote...",
    success: "Listo. Te vemos ahí.",
    successPosition: (n: number) => `Eres el #${n} en la lista.`,
    alreadyRegistered: "Ya estás en la lista. Te avisamos pronto.",
    error: "Algo falló. Inténtalo de nuevo.",
    legal1: "Al continuar aceptas los",
    legalTerms: "términos",
    legal2: "y la",
    legalPrivacy: "política de privacidad",
    legal3: ".",
  },
} as const;
