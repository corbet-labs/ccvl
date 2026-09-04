// Editorial rule for the entire CV:
// Maximize information density: every word and syllable must add a relevant signal.
// Each statement should communicate at least one of: outcome, scale, recognizable
// reference, ownership, or relevant method. Prefer Google XYZ phrasing: lead with
// impact, quantify it where possible, then state how it was achieved. Remove filler,
// defensive qualifiers, generic duties, and duplicated meaning. Write concisely and
// confidently without inventing facts; selective emphasis and compression are expected.
// Every bullet must remain exactly one rendered line and use 80–100% of the
// available line width, targeting 90%; the renderer enforces this contract.
// Add signal, never filler, when a bullet is too short.
// If verified content cannot fill that range, identify the missing dimension
// (outcome, metric, scope, reference, ownership, or method) and ask for the
// relevant fact instead of padding or weakening the wording.

#import "../../shared/styles/document.typ": *
#import "../../shared/components/header.typ": application-header
#import "../../shared/application.typ": validate-application
#import "../../shared/line-contract.typ": measured-lines
#import "../../shared/profile.typ": profile
#show: document-style.with(locale: "de-ch")
#set document(title: "Curriculum Vitae | " + profile.name, author: (profile.name,))

// Page count is selected at compile time: 2 = core, 3 = projects, 4 = competencies.
#let cv-pages = int(sys.inputs.at("cv-pages", default: "4"))
#assert(cv-pages >= 2 and cv-pages <= 4, message: "cv-pages must be 2, 3, or 4")
#let application-path = sys.inputs.at("application", default: "/cvl/general/de-ch/application.json")
#let application = json(application-path)
#validate-application(application, expected-language: "de-CH", require-cv: true)

#let brand(body) = box(body)
#let cv-header() = application-header(locale: "de-ch")
#let cv-pagebreak() = [
  #pagebreak()
  #cv-header()
]

#cv-header()

#block(breakable: false)[
  #cv-compact-heading[Summary]
  #measured-lines("cv.summary", "cv-summary", application.tailored_cv.summary)
]

#block(breakable: false)[
  #cv-compact-heading[Erfahrung]
  // ccvl-station: cenvion
  #cv-h[Infrastructure Investments & Asset Management: #brand[CENVION]]
  #v(6.3pt)
  #cv-s[Associate Intern | Infrastructure Investments · Jan 2026 – Mär 2026 (plus freie Mitarbeit) · Wollerau (CH)]
  #v(7.35pt)
  #cv-b[#brand[Claude] für Investment Reporting eingeführt; GenAI in Analyse- und Berichtsworkflows des Teams integriert]
  #v(8.4pt)
  #cv-b[RAG-basierte KI-Suche über Projekt- und Portfoliodaten entwickelt; internes Wissen durchsuchbar gemacht]
  #v(8.4pt)
  #cv-b[Excel-Projektfinanzierungsmodelle erstellt; Cashflows, Renditen und Finanzierungsszenarien analysiert]
  #cv-entry-gap()
  // ccvl-station: swisscom
  #cv-h[Cloud Strategy & Transformation: #brand[Swisscom Financial Services]]
  #v(6.3pt)
  #cv-s[Executive Assistant & Consultant | B2B & Infrastruktur · Jun 2024 – Mär 2025 · Bern + Zürich]
  #v(7.35pt)
  #cv-b[Achtstellige Infrastrukturinvestitionen im SteerCo präsentiert; Optionen mit Senior Stakeholdern diskutiert]
  #v(8.4pt)
  #cv-b[Lieferantenverhandlungen über CHF 10 Mio. begleitet; sofort CHF 100k+ Einsparpotenzial identifiziert]
  #v(8.4pt)
  #cv-b[Cloud-Ökonomie und 2× Rechendichte unter DC-Limits modelliert; für TOM-Workstream ausgewählt]
  #cv-entry-gap()
  // ccvl-station: airbus
  #cv-h[AI Engineering: #brand[AIRBUS Defence & Space]]
  #v(6.3pt)
  #cv-s[Risk & Compliance Analyst | KI/ML-Masterarbeit · Jul 2023 – Mär 2024 · Ingolstadt]
  #v(7.35pt)
  #cv-b[Sicherheitskritische Daten aus 20+ Jahren per ML ausgewertet & für Risiko- und Kostenanalysen genutzt]
  #v(8.4pt)
  #cv-b[Einzelfall: Sechsstelliges Einsparpotenzial p. a.; standortübergreifende achtstellige Investition ausgelöst]
  #v(8.4pt)
  #cv-b[KI-Pilot von Grund auf für 3 Fachbereiche entwickelt; Stakeholder mit Business Case überzeugt]
  #cv-entry-gap()
  // ccvl-station: covendit
  #cv-h[M&A & Corporate Finance: #brand[COVENDIT]]
  #v(6.3pt)
  #cv-s[Investment Banking Analyst | Werkstudent · Apr 2022 – Jun 2022 · Frankfurt]
  #v(7.35pt)
  #cv-b[Live Buy-/Sell-Side-M&A-Mandate begleitet; DCF-/Multiples-Excel-Modelle, Teaser und IMs erstellt]
  #v(8.4pt)
  #cv-b[KI-Longlisting vor ChatGPT entwickelt; Target-Screening automatisiert, Recherchezeit 80 % reduziert]
  #v(8.4pt)
  #cv-b[PE-Kunden zu Targets beraten; Retainer gewonnen und Rückkehrangebot auf Associate-Level erhalten]
  #cv-entry-gap()
  // ccvl-station: nexgen
  #cv-h[Strategie- & Technologieberatung: #brand[NEXGEN Business Consultants]]
  #v(6.3pt)
  #cv-s[Junior Consultant (Werkstudent) | Banking-IT & Regulierung · Apr 2022 – Jun 2022 · Frankfurt]
  #v(7.35pt)
  #cv-b[BAIT | MaRisk: Regeln für T+1-Settlement in Cloud-Migrationsleitfaden für Tier-1-Banking-IT übersetzt]
  #v(8.4pt)
  #cv-b[ETL-Engpass für Kundenpitch diagnostiziert; Laufzeit um 99 % von 24 h auf 15 min reduziert]
  #v(8.4pt)
  #cv-b[Regulatorik- und IT-Analysen für Fachbeiträge und Kundenpitches aufbereitet; Mandatsakquise unterstützt]
  #cv-entry-gap()
  // ccvl-station: consulting-venture
  #cv-h[Management- & Technologieberatung: #brand[A Softer Space & Corbet Consulting]]
  #v(6.3pt)
  #cv-s[Head of Business Development | Management Consultant · Jan 2018 – Jun 2023 · CH, DE, IS, UK]
  #v(7.35pt)
  #cv-b[Über Trusted-Advisor-Vertrieb auf mittleren sechsstelligen Umsatz in vier europäischen Märkten skaliert]
  #v(8.4pt)
  #cv-b[Management- & IT-Mandate zu Leadership, Prozessen, Cloud und DLT von Analyse bis Umsetzung geführt]
  #v(8.4pt)
  #cv-b[Projekt-P&L ganzheitlich gesteuert: Akquise, Angebote, Pricing, Verträge, Budgets, Margen und Cashflow]
  #cv-entry-gap()
  // ccvl-station: student-consulting
  #cv-h[Studentische Unternehmens- & Innovationsberatung]
  #v(6.3pt)
  #cv-s[GREEN Finance Consulting (BDSU) | Enactus | AIESEC · 2016 – 2023 · je 2 Semester · Frankfurt]
  #v(7.35pt)
  #cv-b[GREEN: Stipendienabwicklung auf 10× Kapazität skaliert; Datenbanksystem für Roland Berger entwickelt]
  #v(8.4pt)
  #cv-b[ENACTUS X: Social Venture für Wohnungslose mitaufgebaut; Jobs geschaffen und Medienresonanz erzielt]
  #v(8.4pt)
  #cv-b[AIESEC: International Placements mit DAX-Unternehmen koordiniert; Talent-Prozesse per CRM digitalisiert]
  #cv-entry-gap()
  // ccvl-station: teaching-research-venture
  #cv-h[Lehre, Marktforschung & Unternehmertum]
  #v(6.3pt)
  #cv-s[Goethe-Universität Frankfurt | mehrere Arbeitgeber | selbstständig · Frankfurt]
  #v(7.35pt)
  #cv-b[Tutor (für 3 Jahre gewählt) & Nachhilfe: Angewandte Statistik (SPSS, Python, R) & Mathematik]
  #v(8.4pt)
  #cv-b[Marktforschung: 50+ CEOs interviewt und 1.000+ Gespräche analysiert, Auswertungen & Dashboards]
  #v(8.4pt)
  #cv-b[Eigene Nebentätigkeit über 16 Jahre aufgebaut und geführt; vom technischen Service bis zum eCommerce]
]

#cv-pagebreak()

#block(breakable: false)[
  #cv-compact-heading[Bildung]
  #cv-hu[Stipendien: *Studienstiftung (Top 1%) | CDI (Top 4%, vollfinanziert) | Sandvoss (MSc & BSc)*]
  #cv-entry-gap()
  // ccvl-station: executive-education
  #cv-h[Executive Education]
  #v(6.3pt)
  #cv-s[Collège des Ingénieurs (CDI) · Paris – München – Turin · 2024 – 2025 · Notenschnitt: A (GPA 4.0)]
  #v(7.35pt)
  #cv-b[Summer School: #brand[Schwarz Digits] als Junior Consultant zum EU AI Act beraten; Implikationen bewertet]
  #v(8.4pt)
  #cv-b[Case Studies: Projektfinanzierung (NPV/ROI), Szenarioanalyse & Kapitalallokation unter Unsicherheit]
  #cv-entry-gap()
  // ccvl-station: physics-degrees
  #cv-h[M.Sc. & B.Sc. Physik]
  #v(6.3pt)
  #cv-s[Goethe-Universität Frankfurt · Abschluss 2024 · Note: 1,0 (DE) | 6,0 (CH) | GPA 4.0]
  #v(7.35pt)
  #cv-b[Schwerpunkte: KI/ML (1,0) | High-Tech-IP (1,15) | Elektronik (1,3) | Biophysik (1,3) | Chemie (1,0)]
  #v(8.4pt)
  #cv-b[Forschung: Nahinfrarotspektroskopie | Terahertz-Bildgebung | Beschleunigerphysik (LINAC)]
  #cv-entry-gap()
  // ccvl-station: psychology-degree
  #cv-h[B.Sc. Psychologie]
  #v(6.3pt)
  #cv-s[Goethe-Universität Frankfurt · Abschluss 2017 · Note: 1,6 (DE) | 5,6 (CH) | GPA 3.7]
  #v(7.35pt)
  #cv-b[Schwerpunkte: KI/ML & Neurowissenschaften | AR/VR-Trainings | Klinische/Organisationspsychologie (1,0)]
  #v(8.4pt)
  #cv-b[FIAS-Forschung (9 Mon.): Stereosehen & neuronale Abstimmung per ML modelliert; Empathie quantifiziert]
  #cv-entry-gap()
  #cv-hu[Matura (Abitur): *1,0 (DE) | 6,0 (CH) · Jahrgangsbester · Mathe-Olympiade · Schülerakademie*]
]

#block(breakable: false)[
  #cv-compact-heading[Professional Development]
  // ccvl-station: certificates
  #cv-h[Zertifikate & Weiterbildung]
  #v(6.3pt)
  #cv-s[Finanzen | Datenanalyse | GenAI | Leadership]
  #v(7.35pt)
  #cv-b[CFI-Zertifikatsprogramme (laufend): BIDA | CBCA | CMSA | FMVA; Trainings: Excel (VBA) | BI (Tableau)]
  #v(8.4pt)
  #cv-b[Weitere Trainings: GenAI | Automatisierung | Rhetorik | Verhandlung | Leadership | Kommunikation]
  #cv-entry-gap()
  // ccvl-station: consulting-finance-networks
  #cv-h[Consulting- & Finance-Netzwerke]
  #v(6.3pt)
  #cv-s[Marktnähe durch laufenden Austausch mit Praktikern und erfahrenen Sparringspartnern]
  #v(7.35pt)
  #cv-b[Im Studium: Bain Spark | BCG Emeralds | WFI Consulting Cup; BDSU- & Studienstiftung-Alumnus]
  #v(8.4pt)
  #cv-b[SECA Young Member; vernetzt mit Praktikern aus Schweizer PE, VC und Corporate Development]
  #cv-entry-gap()
  // ccvl-station: technology-communities
  #cv-h[Tech-Communities & Konferenzen]
  #v(6.3pt)
  #cv-s[Am Puls neuer Technologien, Werkzeuge und praktischer Anwendungen]
  #v(7.35pt)
  #cv-b[Swiss Python Summit & Web Zurich (2025) mitorganisiert; AV-Betrieb und Sprecherkoordination]
  #v(8.4pt)
  #cv-b[Digitale Gesellschaft | LUG | digitalswitzerland | Impact Hub; Praxisfokus: GenAI & Digitale Souveränität]
]

#block(breakable: false)[
  #cv-compact-heading[Engagement]
  // ccvl-station: crisis-support
  #cv-h[Harm Reduction & Krisenunterstützung]
  #v(6.3pt)
  #cv-s(min-fill: 20, target-fill: 35)[Krisenintervention & Akuthilfe]
  #v(7.35pt)
  #cv-b[Mehrfach lebensrettend eingegriffen; Ersthilfe geleistet und Übergabe an Rettungskräfte sichergestellt]
  #v(8.4pt)
  #cv-b[Akute psychosoziale Krisen deeskaliert; Betroffene stabilisiert, orientiert und an Fachstellen vermittelt]
  #cv-entry-gap()
  // ccvl-station: mentoring
  #cv-h[Beratung, Mentoring & Fachschaft]
  #v(6.3pt)
  #cv-s[Frühe digitale Jugendberatung | fachübergreifender Wissenstransfer]
  #v(7.35pt)
  #cv-b[Als einer von wenigen Männern bei Kids Hotline zu Identität, Körperbild & Selbstzweifeln beraten]
  #v(8.4pt)
  #cv-b[Psychologie-Mentoring für alle Jahrgänge mitentwickelt; Fachschaft Physik & Night of Science unterstützt]
]

#block(breakable: false)[
  #cv-compact-heading[Persönliches]
  // ccvl-station: family-responsibility
  #cv-h[Bildungsaufstieg & Verantwortung]
  #v(6.3pt)
  #cv-s[First Generation Academic | Bezugsperson für Geschwister (6 bzw. 12 Jahre jünger) | Pflegezeit 2025]
  #v(7.35pt)
  #cv-b[Geschwister persönlich & finanziell unterstützt: Abitur (1,0) | Medizinstudium | Unternehmensgründung]
  #v(8.4pt)
  #cv-b[Pflegezeit 2025: Versorgung, Finanzierung & Langzeitpflege meiner Mutter geplant und organisiert]
  #cv-entry-gap()
  // ccvl-station: open-source-community
  #cv-h[Teilen & Mitgestalten]
  #v(6.3pt)
  #cv-s[Interkulturelles Zusammenleben | internationale Zusammenarbeit an Open-Source-Software]
  #v(7.35pt)
  #cv-b[Mit 20+ Menschen aus 10+ Ländern zusammengelebt; interkulturellen Austausch aktiv gestaltet]
  #v(8.4pt)
  #cv-b[50+ Open-Source-Projekte veröffentlicht; an weiteren mitgewirkt, zuletzt oo7 (Cybersecurity)]
]

#if cv-pages >= 3 [
  #cv-pagebreak()

  #cv-superheading[Projekte & Initiativen]
  #block(breakable: false)[
    #cv-spacious-heading[Laufend]
    // ccvl-project: product-innovation
    #cv-h[Produktinnovation & Engineering]
    #v(6.3pt)
    #cv-s[Produktreleases 2026: Local-First-KI | Remote Development | Systems UX]
    #v(7.35pt)
    #cv-b[cfetch: lokales KI-Gedächtnis (RAG) | bis zu 93,4 % weniger Kontextballast | \>15 % Tokeneinsparpotenzial]
    #v(8.4pt)
    #cv-b[cterm: Remote-First-Terminal für KI-Coding | dotkeeper: P2P-Code-Sync | cbar: Cross-Machine App Matrix]
    #cv-entry-gap()
    // ccvl-project: declarative-systems-platform
    #cv-h[Deklarative Systemplattform]
    #v(6.3pt)
    #cv-s[Produktreleases 2026: 50+ Systembausteine für NixOS, Arch & GCP]
    #v(7.35pt)
    #cv-b[NixOS & Arch: Hosts, Storage, Netzwerk, Desktops & Apps in einer reproduzierbaren Plattform vereint]
    #v(8.4pt)
    #cv-b[NixOS, k3s, Argo CD & OpenTofu auf GCP & Bare Metal ausgerollt | signierte Updates | Prüfung | Rollback]
    #cv-entry-gap()
    // ccvl-project: content-innovation
    #cv-h[Content-Innovation & KI-gestützte Medien]
    #v(6.3pt)
    #cv-s[Neue Formate: 4K-Video, GenAI & ausfallsicheres Audio · seit 2025]
    #v(7.35pt)
    #cv-b[4K-Mehrkamera-Videos für Swiss Python Summit, Winterkongress & CoSin (Chaos Singularity) produziert]
    #v(8.4pt)
    #cv-b[ComfyUI für GenAI auf eigener GPU betrieben | caudio: 3-Host-Audio-Routing mit Failover & Recovery]
    #cv-entry-gap()
    // ccvl-project: careervector-jobcache
    #cv-h[CareerVector & JobCache]
    #v(6.3pt)
    #cv-s[KI-native Karriereplattform & Jobdaten-Pipeline · live seit 2025]
    #v(7.35pt)
    #cv-b[CareerVector: KI-native kollaborative Karriereplattform für Web, Desktop & Terminal mit Typst-Rendering]
    #v(8.4pt)
    #cv-b[JobCache: 91 Rust-Adapter für kontinuierliche Erfassung & Deduplizierung von CH/EU-Stellenanzeigen]
    #cv-entry-gap()
    // ccvl-project: private-ai-cloud
    #cv-h[Private KI- & Cloud-Plattform]
    #v(6.3pt)
    #cv-s[Digitale Souveränität im Produktivbetrieb für 10+ Nutzer · seit 2024]
    #v(7.35pt)
    #cv-b[30+ Dienste und 100+ TB mit SSO, Monitoring, Backups & Disaster Recovery end-to-end betrieben]
    #v(8.4pt)
    #cv-b[Lokale LLMs & KI-Agenten auf eigener GPU-Infrastruktur betrieben | \>90 % günstiger als Public Cloud]
  ]

  #block(breakable: false)[
    #cv-spacious-heading[Realisiert]
    // ccvl-project: management-buy-in
    #cv-h[Management Buy-In: Deal Origination & Due Diligence]
    #v(6.3pt)
    #cv-s[Indischer IT-Outsourcer · eigenständiges MBI bis zum Kaufentscheid · 2022]
    #v(7.35pt)
    #cv-b[Indischen IT-Outsourcer als MBI-Ziel identifiziert und End-to-End Due Diligence eigenständig durchgeführt]
    #v(8.4pt)
    #cv-b[Akquisitionsthese entwickelt | strategischen Fit, Chancen & Risiken bis zum finalen Go/No-Go bewertet]
    #cv-entry-gap()
    // ccvl-project: solar-recovery
    #cv-h[Solar-KMU: Incident Recovery & Cloud-Migration]
    #v(6.3pt)
    #cv-s[Betriebskritische Systeme für Vertrieb & Felddienst · 2022]
    #v(7.35pt)
    #cv-b[Kernsystem am ersten Tag wiederhergestellt; Vertrieb und Felddienst bis zur Ablösung arbeitsfähig gehalten]
    #v(8.4pt)
    #cv-b[Cloud-Optionen gegen Betriebsanforderungen geprüft; sechs- bis siebenstellige Fehlinvestition vermieden]
    #cv-entry-gap()
    // ccvl-project: leadership-digital-pivot
    #cv-h[Leadership Advisory: Digitaler Pivot]
    #v(6.3pt)
    #cv-s[Frankfurter Leadership-Marke · Hybridformat & neue Vertriebskanäle · 2022]
    #v(7.35pt)
    #cv-b[Performance-Leadership-Angebot für hybride Delivery überarbeitet und On-Demand-Infrastruktur aufgebaut]
    #v(8.4pt)
    #cv-b[Funnel an Kundenpainpoints ausgerichtet; Umsatz diversifiziert und Kurse bei Haufe Akademie platziert]
    #cv-entry-gap()
    // ccvl-project: crypto-infrastructure
    #cv-h[Krypto-Infrastruktur: Business Case & Betrieb]
    #v(6.3pt)
    #cv-s[Mining-Piloten vom Business Case bis zum Betrieb · mehrere Kunden · 2021]
    #v(7.35pt)
    #cv-b[Pilot und Betriebsmodell dimensioniert und kalkuliert; Hardware beschafft und operative Risiken gesteuert]
    #v(8.4pt)
    #cv-b[Mining-Betrieb termingerecht, stabil und mit Monitoring aufgebaut; Hashrate via Custom-Firmware optimiert]
    #cv-entry-gap()
    // ccvl-project: it-services-ecommerce
    #cv-h[IT-Services & automatisierter eCommerce]
    #v(6.3pt)
    #cv-s[Eigenes Geschäft · Exit zu 80 % des Buchwerts · 2009 – 2025]
    #v(7.35pt)
    #cv-b[Hardwarehandel, Diagnose, Custom Builds & Reparaturen für KMU/B2C-Kunden aufgebaut & betrieben]
    #v(8.4pt)
    #cv-b[Listing, Bestand, Tracking und Logistik des fünfstelligen eBay-Betriebs per Mini-ERP automatisiert]
  ]
]

// Page 4 is a machine-retrieval layer: its noun-based entries may include
// adjacent and independently developed knowledge, but never imply employment,
// ownership or results. Use literal ASCII pipes with spaces between list items,
// keep canonical phrases intact, and target 92-98% width without wrapping.
#if cv-pages >= 4 [
  #cv-pagebreak()

  #cv-superheading[Kompetenzen & KI Keywords]
  #block(breakable: false)[
    #cv-spacious-heading[AI, Data & Technologie]
    // ccvl-competency: ai-products-tooling
    #cv-h[AI-Produkte, Tooling & Modellökosysteme]
    #v(7.35pt)
    #cv-b[US AI Tooling: Anthropic Claude Code | Claude Desktop | OpenAI Codex | ChatGPT Desktop | Copilot]
    #v(8.4pt)
    #cv-b[Open Source AI Tooling: OpenCode | Ollama | vLLM | llama.cpp | Open WebUI | Hugging Face | Langfuse]
    #v(8.4pt)
    #cv-b[Open Model Ecosystems: GLM | DeepSeek | Qwen | Kimi | MiniMax | MiMo | Llama | Mistral | Gemma]
    #cv-entry-gap()
    // ccvl-competency: applied-ai-data
    #cv-h[AI Engineering, Data Science & Automatisierung]
    #v(7.35pt)
    #cv-b[AI Engineering: Large Language Models (LLMs) | Retrieval-Augmented Generation (RAG) | Embeddings]
    #v(8.4pt)
    #cv-b[Agentic Systems: AI Agents | Multi-Agent Systems | Model Context Protocol (MCP) | Agent SDKs]
    #v(8.4pt)
    #cv-b[Data Science & ML: Statistik | Machine Learning | Zeitreihen | Predictive Modelling | Experimente | R]
    #cv-entry-gap()
    // ccvl-competency: software-infrastructure
    #cv-h[Software Engineering, Web & Infrastruktur]
    #v(7.35pt)
    #cv-b[Software Engineering: Python | Rust | Go | Java | APIs | Git | CI/CD | Systems Programming | Testing]
    #v(8.4pt)
    #cv-b[Web Development & Publishing: TypeScript | JavaScript | Svelte | Astro | HTML | CSS | Markdown | Typst]
    #v(8.4pt)
    #cv-b[Data & Infrastructure: SQL | Data Pipelines | Linux | Kubernetes | GitOps | Infrastructure as Code (IaC)]
    #cv-spacious-heading[Strategie, Innovation & Transformation]
    // ccvl-competency: innovation-management
    #cv-h[Innovationsmanagement & Emerging Technologies]
    #v(7.35pt)
    #cv-b[Innovation Management: Innovation Pipeline | Stage-Gate | Incremental Innovation | Disruptive Innovation]
    #v(8.4pt)
    #cv-b[Technology Scouting: Emerging Technologies | Trendanalyse | Horizon Scanning | Technologiebewertung]
    #v(8.4pt)
    #cv-b[Produktinnovation: Product Discovery | Prototyping | Proof of Concept (PoC) | MVP | Marktvalidierung]
    #cv-entry-gap()
    // ccvl-competency: strategy
    #cv-h[Unternehmens-, Wachstums- & Technologiestrategie]
    #v(7.35pt)
    #cv-b[Corporate Strategy: Strategische Planung | Szenarioplanung | Wettbewerbsanalyse | Decision Support]
    #v(8.4pt)
    #cv-b[Growth Strategy: Business Development | Markteintritt | Go-to-Market | Partnerschaften | Pricing | B2B]
    #v(8.4pt)
    #cv-b[Technology Strategy: AI Strategy | Roadmaps | Business Cases | Enterprise Architecture | TCO | FinOps]
    #cv-entry-gap()
    // ccvl-competency: transformation-governance
    #cv-h[Transformation, Operating Models & Governance]
    #v(7.35pt)
    #cv-b[Operating Models: Target Operating Model (TOM) | Organisationsdesign | Decision Rights | Rollendesign]
    #v(8.4pt)
    #cv-b[Change & Value Creation: AI Adoption | Change Management | Benefits Realisation | Cost Transformation]
    #v(8.4pt)
    #cv-b[AI Governance: EU AI Act | Responsible AI | Model Risk | DORA | Operational Resilience | DSGVO]
    #cv-spacious-heading[Finanzen, Investments & Märkte]
    // ccvl-competency: finance-ma
    #cv-h[Finance Transformation, Corporate Finance & M&A]
    #v(7.35pt)
    #cv-b[CFO Agenda: Finance Platform | Finance Data Architecture | Planung & Forecasting | AI-enabled Finance]
    #v(8.4pt)
    #cv-b[Corporate Finance: Financial Modelling | Valuation | DCF | Multiples | Project Finance | NPV | IRR | DSCR]
    #v(8.4pt)
    #cv-b[M&A: Target Screening | Financial Due Diligence | Synergy Assessment | Post-Merger Integration (PMI)]
    #cv-entry-gap()
    // ccvl-competency: private-markets
    #cv-h[Private Markets & Investment Management]
    #v(7.35pt)
    #cv-b[Private Markets: Private Equity | Private Credit | Infrastructure Investments | Real Estate | Secondaries]
    #v(8.4pt)
    #cv-b[Investment Strategies: Buyouts | Growth Equity | Direct Lending | Distressed Debt | Special Situations]
    #v(8.4pt)
    #cv-b[CIO Office: Investment Strategy | Multi-Asset | Portfolio Construction | Strategic Asset Allocation (SAA)]
    #cv-entry-gap()
    // ccvl-competency: trading-risk
    #cv-h[Trading, Quantitative Finance & Risiko]
    #v(7.35pt)
    #cv-b[Energy & Commodity Markets: Power Trading | Day-Ahead | Intraday | Gas/LNG | Metals | Carbon | Freight]
    #v(8.4pt)
    #cv-b[Systematic Trading: Alpha Signals | Backtesting | Trade Execution | Futures | Swaps | Options | Hedging]
    #v(8.4pt)
    #cv-b[Quantitative Risk: PnL | Value at Risk (VaR) | Stress Testing | Monte Carlo | Optionsbewertung | Volatilität]
  ]
]

#assert-page-count(cv-pages)
