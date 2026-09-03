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
#show: document-style.with(locale: "en-ch")

// Page count is selected at compile time: 2 = core, 3 = projects, 4 = competencies.
#let cv-pages = int(sys.inputs.at("cv-pages", default: "4"))
#assert(cv-pages >= 2 and cv-pages <= 4, message: "cv-pages must be 2, 3, or 4")
#let application-path = sys.inputs.at("application", default: "/cvl/general/en-ch/application.json")
#let application = json(application-path)
#validate-application(application, expected-language: "en-CH", require-cv: true)

#let brand(body) = box(body)
#let cv-header() = application-header(locale: "en-ch")
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
  #cv-compact-heading[Experience]
  // ccvl-station: cenvion
  #cv-h[Infrastructure Investments & Asset Management: #brand[CENVION]]
  #v(6.3pt)
  #cv-s[Associate Intern | Infrastructure Investments · Jan 2026 – Mar 2026 (plus freelance work) · Wollerau (CH)]
  #v(7.35pt)
  #cv-b[Introduced #brand[Claude] for investment reporting; embedded GenAI in the team's analysis and reporting workflows]
  #v(8.4pt)
  #cv-b[Developed RAG-based AI search across project and portfolio data; made internal knowledge searchable]
  #v(8.4pt)
  #cv-b[Built Excel project-finance models; analysed cash flows, returns and financing scenarios]
  #cv-entry-gap()
  // ccvl-station: swisscom
  #cv-h[Cloud Strategy & Transformation: #brand[Swisscom Financial Services]]
  #v(6.3pt)
  #cv-s[Executive Assistant & Consultant | B2B & Infrastructure · Jun 2024 – Mar 2025 · Bern + Zurich]
  #v(7.35pt)
  #cv-b[Presented eight-figure infrastructure investments in SteerCo; discussed options with senior stakeholders]
  #v(8.4pt)
  #cv-b[Supported CHF 10m+ supplier negotiations; identified CHF 100k+ immediate savings potential]
  #v(8.4pt)
  #cv-b[Modelled cloud economics and 2× compute density under DC constraints; selected for the TOM workstream]
  #cv-entry-gap()
  // ccvl-station: airbus
  #cv-h[AI Engineering: #brand[AIRBUS Defence & Space]]
  #v(6.3pt)
  #cv-s[Risk & Compliance Analyst | AI/ML Master's Thesis · Jul 2023 – Mar 2024 · Ingolstadt]
  #v(7.35pt)
  #cv-b[Analysed 20+ years of safety-critical data with ML; produced signals for risk and cost analyses]
  #v(8.4pt)
  #cv-b[Single case: quantified six-figure annual savings potential; triggered eight-figure multi-site investment]
  #v(8.4pt)
  #cv-b[Tailored 0-to-1 AI pilot to three departments’ objectives; secured stakeholder buy-in with business case]
  #cv-entry-gap()
  // ccvl-station: covendit
  #cv-h[M&A & Corporate Finance: #brand[COVENDIT]]
  #v(6.3pt)
  #cv-s[Investment Banking Analyst | Working Student · Apr 2022 – Jun 2022 · Frankfurt]
  #v(7.35pt)
  #cv-b[Supported live buy- and sell-side M&A mandates; built DCF/multiples Excel models, teasers and IMs]
  #v(8.4pt)
  #cv-b[Built AI-assisted longlisting before ChatGPT; automated target screening and cut research time by 80%]
  #v(8.4pt)
  #cv-b[Advised PE clients on targets; won a retainer and received an Associate-level return offer]
  #cv-entry-gap()
  // ccvl-station: nexgen
  #cv-h[Strategy & Technology Consulting: #brand[NEXGEN Business Consultants]]
  #v(6.3pt)
  #cv-s[Junior Consultant (Working Student) | Banking Technology & Regulation · Apr 2022 – Jun 2022 · Frankfurt]
  #v(7.35pt)
  #cv-b[BAIT | MaRisk: Translated rules for T+1 settlement into Tier-1 banking IT cloud migration guidance]
  #v(8.4pt)
  #cv-b[Diagnosed an ETL bottleneck for a client pitch; cut processing time by 99%, from 24 hours to 15 minutes]
  #v(8.4pt)
  #cv-b[Prepared regulatory/IT analysis for thought leadership and pitches; supported business development]
  #cv-entry-gap()
  // ccvl-station: consulting-venture
  #cv-h[Management & Technology Consulting: #brand[A Softer Space & Corbet Consulting]]
  #v(6.3pt)
  #cv-s[Head of Business Development | Management Consultant · Jan 2018 – Jun 2023 · CH, DE, IS, UK]
  #v(7.35pt)
  #cv-b[Scaled trusted-advisor consulting sales to mid-six-figure revenue across four European markets]
  #v(8.4pt)
  #cv-b[Delivered management | IT engagements across leadership | process | cloud | DLT from analysis to delivery]
  #v(8.4pt)
  #cv-b[Managed project P&L end to end: acquisition, proposals, pricing, contracts, budgets, margins and cash flow]
  #cv-entry-gap()
  // ccvl-station: student-consulting
  #cv-h[Student Management & Innovation Consulting]
  #v(6.3pt)
  #cv-s[GREEN Finance Consulting (BDSU) | Enactus | AIESEC · 2016 – 2023 · 2 semesters each · Frankfurt]
  #v(7.35pt)
  #cv-b[GREEN: Scaled scholarship operations to 10× capacity; developed database system for Roland Berger]
  #v(8.4pt)
  #cv-b[ENACTUS X: Co-built social venture for homeless people; created jobs and generated media coverage]
  #v(8.4pt)
  #cv-b[AIESEC: Coordinated international placements with DAX firms; digitised talent-team workflows via CRM]
  #cv-entry-gap()
  // ccvl-station: teaching-research-venture
  #cv-h[Teaching, Market Research & Entrepreneurship]
  #v(6.3pt)
  #cv-s[Goethe University Frankfurt | multiple employers | self-employed · Frankfurt]
  #v(7.35pt)
  #cv-b[Elected tutor for three consecutive years & private tutor: applied statistics (SPSS, Python, R) and maths]
  #v(8.4pt)
  #cv-b[Market research: interviewed 50+ CEOs and analysed 1,000+ calls; produced analyses and dashboards]
  #v(8.4pt)
  #cv-b[Built and ran my own side venture for 16 years, spanning technical services, repairs and eCommerce]
]

#cv-pagebreak()

#block(breakable: false)[
  #cv-compact-heading[Education]
  #cv-hu[Scholarships: *Studienstiftung (Top 1%) | CDI (Top 4%, fully funded) | Sandvoss (MSc & BSc)*]
  #cv-entry-gap()
  // ccvl-station: executive-education
  #cv-h[Executive Education]
  #v(6.3pt)
  #cv-s[Collège des Ingénieurs (CDI) · Paris – Munich – Turin · 2024 – 2025 · Average grade: A (GPA 4.0)]
  #v(7.35pt)
  #cv-b[Summer School: Advised #brand[Schwarz Digits] as Junior Consultant on the EU AI Act; assessed its implications]
  #v(8.4pt)
  #cv-b[Case studies: Project finance (NPV/ROI), scenario analysis and capital allocation under uncertainty]
  #cv-entry-gap()
  // ccvl-station: physics-degrees
  #cv-h[M.Sc. & B.Sc. Physics]
  #v(6.3pt)
  #cv-s[Goethe University Frankfurt · Graduated 2024 · Grade: 1.0 (DE) | 6.0 (CH) | GPA 4.0]
  #v(7.35pt)
  #cv-b[Focus: AI/ML (1.0) | high-tech IP (1.15) | electronics (1.3) | biophysics (1.3) | chemistry (1.0)]
  #v(8.4pt)
  #cv-b[Research: Near-infrared spectroscopy | terahertz imaging | accelerator physics (LINAC)]
  #cv-entry-gap()
  // ccvl-station: psychology-degree
  #cv-h[B.Sc. Psychology]
  #v(6.3pt)
  #cv-s[Goethe University Frankfurt · Graduated 2017 · Grade: 1.6 (DE) | 5.6 (CH) | GPA 3.7]
  #v(7.35pt)
  #cv-b[Focus: AI/ML & neuroscience | AR/VR training | clinical/organisational psychology (1.0)]
  #v(8.4pt)
  #cv-b[Research at #brand[FIAS] (9 mos.): Modelled stereovision and neural tuning with ML; quantified empathy]
  #cv-entry-gap()
  #cv-hu[Matura (Abitur): *1.0 (DE) | 6.0 (CH) · Top of graduating class · Maths Olympiad · Student Academy*]
]

#block(breakable: false)[
  #cv-compact-heading[Professional Development]
  // ccvl-station: certificates
  #cv-h[Certifications & Training]
  #v(6.3pt)
  #cv-s[Finance | Data Analytics | GenAI | Leadership]
  #v(7.35pt)
  #cv-b[CFI certification programmes (ongoing): BIDA | CBCA | CMSA | FMVA; training: Excel (VBA) | BI (Tableau)]
  #v(8.4pt)
  #cv-b[Additional training: GenAI | automation | public speaking | negotiation | leadership | communication]
  #cv-entry-gap()
  // ccvl-station: consulting-finance-networks
  #cv-h[Consulting & Finance Networks]
  #v(6.3pt)
  #cv-s[Market proximity through regular exchange with practitioners and experienced sparring partners]
  #v(7.35pt)
  #cv-b[At university: Bain Spark | BCG Emeralds | WFI Consulting Cup; BDSU & Studienstiftung alumnus]
  #v(8.4pt)
  #cv-b[SECA Young Member; connected with practitioners across Swiss PE, VC and Corporate Development]
  #cv-entry-gap()
  // ccvl-station: technology-communities
  #cv-h[Tech Communities & Conferences]
  #v(6.3pt)
  #cv-s[Close to emerging technologies, tools and practical applications]
  #v(7.35pt)
  #cv-b[Co-organised Swiss Python Summit & Web Zurich (2025); AV operations and speaker coordination]
  #v(8.4pt)
  #cv-b[Digitale Gesellschaft | LUG | digitalswitzerland | Impact Hub; focus: GenAI & digital sovereignty]
]

#block(breakable: false)[
  #cv-compact-heading[Engagement]
  // ccvl-station: crisis-support
  #cv-h[Harm Reduction & Crisis Support]
  #v(6.3pt)
  #cv-s(min-fill: 25, target-fill: 35)[First aid | psychosocial de-escalation]
  #v(7.35pt)
  #cv-b[Intervened in life-threatening situations multiple times; provided first aid and ensured EMS handover]
  #v(8.4pt)
  #cv-b[De-escalated acute psychosocial crises; stabilised, oriented and referred people to specialist support]
  #cv-entry-gap()
  // ccvl-station: mentoring
  #cv-h[Counselling, Mentoring & Student Representation]
  #v(6.3pt)
  #cv-s[Online youth counselling | cross-disciplinary knowledge transfer]
  #v(7.35pt)
  #cv-b[One of few male Kids Hotline counsellors; supported youth on identity, body image & self-doubt]
  #v(8.4pt)
  #cv-b[Co-developed psychology mentoring across cohorts; supported Physics Student Council & Night of Science]
]

#block(breakable: false)[
  #cv-compact-heading[Personal]
  // ccvl-station: family-responsibility
  #cv-h[Educational Mobility & Family Responsibility]
  #v(6.3pt)
  #cv-s[First-generation academic | education | entrepreneurship | care coordination]
  #v(7.35pt)
  #cv-b[Supported siblings personally & financially: top-grade Abitur (1.0) | medical studies | company launch]
  #v(8.4pt)
  #cv-b[Took family care leave in 2025; coordinated care, financing & long-term support for my mother]
  #cv-entry-gap()
  // ccvl-station: open-source-community
  #cv-h[Intercultural Community & Open-Source Software]
  #v(6.3pt)
  #cv-s[Shared living | international FOSS collaboration]
  #v(7.35pt)
  #cv-b[Lived with 20+ people from 10+ countries; actively fostered intercultural exchange through shared living]
  #v(8.4pt)
  #cv-b[Published 50+ open-source projects; contributed to other projects, most recently oo7 (cybersecurity)]
]

#if cv-pages >= 3 [
  #cv-pagebreak()

  #cv-superheading[Projects & Initiatives]
  #block(breakable: false)[
    #cv-spacious-heading[Ongoing]
    #cv-h[Product Innovation & Engineering]
    #v(6.3pt)
    #cv-s[Product releases 2026: local-first AI | remote development | systems UX]
    #v(7.35pt)
    #cv-b[cfetch: local-first AI memory (RAG) | up to 93.4% less wasted context | \>15% token-saving potential]
    #v(8.4pt)
    #cv-b[cterm: remote-first coding terminal | dotkeeper: P2P code sync | cbar: cross-machine 2D app launcher]
    #cv-entry-gap()
    #cv-h[Declarative Systems Platform]
    #v(6.3pt)
    #cv-s[Product releases 2026: 50+ reusable components for NixOS, Arch & GCP]
    #v(7.35pt)
    #cv-b[Unified hosts, storage, networks, desktops & apps across NixOS and Arch in one reproducible platform]
    #v(8.4pt)
    #cv-b[Deployed NixOS, k3s, Argo CD & OpenTofu on GCP & bare metal | signed updates | health checks | rollback]
    #cv-entry-gap()
    #cv-h[Content Innovation & AI-Enabled Media]
    #v(6.3pt)
    #cv-s[New formats: 4K multi-camera video, GenAI & resilient audio · since 2025]
    #v(7.35pt)
    #cv-b[Produced 4K multi-camera video for Swiss Python Summit, Winter Congress & CoSin (Chaos Singularity)]
    #v(8.4pt)
    #cv-b[Ran GPU-hosted ComfyUI for GenAI media | caudio: audio routing across 3 hosts with failover & recovery]
    #cv-entry-gap()
    #cv-h[CareerVector & JobCache]
    #v(6.3pt)
    #cv-s[AI-native career platform & job-data pipeline · live since 2025]
    #v(7.35pt)
    #cv-b[CareerVector: AI-native career platform across collaborative web, desktop & terminal workflows with Typst]
    #v(8.4pt)
    #cv-b[JobCache: built 91 Rust adapters for continuous, distributed ingestion & deduplication of CH/EU job ads]
    #cv-entry-gap()
    #cv-h[Private AI & Cloud Platform]
    #v(6.3pt)
    #cv-s[Digitally sovereign production platform for 10+ users · since 2024]
    #v(7.35pt)
    #cv-b[Operated 30+ private services and 100+ TB with SSO, monitoring, automated backups & disaster recovery]
    #v(8.4pt)
    #cv-b[Ran local LLMs & AI agents in production on shared GPU infrastructure | \>90% lower cost than public cloud]
  ]

  #block(breakable: false)[
    #cv-spacious-heading[Delivered]
    #cv-h[Management Buy-In: Deal Origination & Due Diligence]
    #v(6.3pt)
    #cv-s[Indian IT outsourcer · independent MBI through the purchase decision · 2022]
    #v(7.35pt)
    #cv-b[Identified an Indian IT outsourcing target for an MBI and independently conducted end-to-end due diligence]
    #v(8.4pt)
    #cv-b[Built the acquisition thesis; assessed strategic fit, opportunities & risks through the final go/no-go decision]
    #cv-entry-gap()
    #cv-h[Solar SME: Incident Recovery & Cloud Migration]
    #v(6.3pt)
    #cv-s[Business-critical systems for sales & field service · 2022]
    #v(7.35pt)
    #cv-b[Restored the core system on day one and kept sales & field service operational until full replacement]
    #v(8.4pt)
    #cv-b[Tested cloud migration options against operating needs; prevented six-to-seven-figure misinvestment]
    #cv-entry-gap()
    #cv-h[Leadership Advisory: Digital Pivot]
    #v(6.3pt)
    #cv-s[Frankfurt-based leadership brand · hybrid delivery & new sales channels · 2022]
    #v(7.35pt)
    #cv-b[Redesigned Performance Leadership offering for scalable hybrid delivery and built on-demand infrastructure]
    #v(8.4pt)
    #cv-b[Aligned funnel to customer pain points; diversified revenue and placed courses with Haufe Akademie]
    #cv-entry-gap()
    #cv-h[Crypto Infrastructure: Business Case & Operations]
    #v(6.3pt)
    #cv-s[Mining pilots from business case to stable operations · multiple clients · 2021]
    #v(7.35pt)
    #cv-b[Sized and costed pilot and operating model; sourced hardware and actively managed operating risks]
    #v(8.4pt)
    #cv-b[Delivered monitored, stable mining operation on schedule; optimised hash rate via custom firmware]
    #cv-entry-gap()
    #cv-h[IT Services & Automated eCommerce]
    #v(6.3pt)
    #cv-s[Independent business · exited at 80% of book value · 2009 – 2025]
    #v(7.35pt)
    #cv-b[Built and ran a hardware business for SME & B2C clients: sales | custom builds | diagnostics | repairs]
    #v(8.4pt)
    #cv-b[Automated listings, inventory, tracking and logistics for five-figure eBay operation through own mini-ERP]
  ]
]

// Page 4 is a machine-retrieval layer: its noun-based entries may include
// adjacent and independently developed knowledge, but never imply employment,
// ownership or results. Use literal ASCII pipes with spaces between list items,
// keep canonical phrases intact, and target 92-98% width without wrapping.
#if cv-pages >= 4 [
  #cv-pagebreak()

  #cv-superheading[Capabilities & AI Keywords]
  #block(breakable: false)[
    #cv-spacious-heading[Innovation, AI & Technology]
    #cv-h[Innovation Management & Emerging Technologies]
    #v(7.35pt)
    #cv-b[Innovation Management: Innovation Pipeline | Stage-Gate | Incremental Innovation | Disruptive Innovation]
    #v(8.4pt)
    #cv-b[Technology Scouting: Emerging Technologies | Trend Analysis | Horizon Scanning | Technology Assessment]
    #v(8.4pt)
    #cv-b[Product Innovation: Product Discovery | Prototyping | Proof of Concept (PoC) | MVP | Market Validation]
    #cv-entry-gap()
    #cv-h[Applied AI, Data & Intelligent Automation]
    #v(7.35pt)
    #cv-b[Generative AI: Large Language Models (LLMs) | Retrieval-Augmented Generation (RAG) | AI Assistants]
    #v(8.4pt)
    #cv-b[Agentic AI: AI Agents | Multi-Agent Systems | Model Context Protocol (MCP) | Intelligent Automation]
    #v(8.4pt)
    #cv-b[Data Science: Statistics | Machine Learning (ML) | Time Series | Predictive Modelling | Experiments | R]
    #cv-entry-gap()
    #cv-h[Software Engineering, Data Platforms & Infrastructure]
    #v(7.35pt)
    #cv-b[Software Engineering: Python | Rust | Go | Java | APIs | Open Source | Systems Programming | Testing]
    #v(8.4pt)
    #cv-b[Data Platforms: SQL | Data Pipelines | Data Modelling | Distributed Systems | Vector Search | Observability]
    #v(8.4pt)
    #cv-b[Digital Infrastructure: Cloud | Data Centres | Linux | Kubernetes | GitOps | Infrastructure as Code (IaC)]
    #cv-spacious-heading[Strategy & Transformation]
    #cv-h[Corporate, Growth & Technology Strategy]
    #v(7.35pt)
    #cv-b[Corporate Strategy: Strategic Planning | Scenario Planning | Competitive Analysis | Decision Support]
    #v(8.4pt)
    #cv-b[Growth Strategy: Business Development | Market Entry | Go-to-Market | Partnerships | Pricing | B2B]
    #v(8.4pt)
    #cv-b[Technology Strategy: AI Strategy | Roadmaps | Business Cases | Enterprise Architecture | TCO | FinOps]
    #cv-entry-gap()
    #cv-h[Transformation, Operating Models & Value Creation]
    #v(7.35pt)
    #cv-b[Operating Models: Target Operating Model (TOM) | Organisational Design | Decision Rights | Role Design]
    #v(8.4pt)
    #cv-b[Change & Adoption: AI Adoption | Change Management | Programme Delivery | Benefits Realisation]
    #v(8.4pt)
    #cv-b[Value Creation: Operational Excellence | Cost Transformation | KPI Design | Turnaround | Restructuring]
    #cv-entry-gap()
    #cv-h[Policy, Regulation & Technology Governance]
    #v(7.35pt)
    #cv-b[Public Policy & Regulatory Affairs: Energy Policy | AI Policy | Defence Procurement | Competition Policy]
    #v(8.4pt)
    #cv-b[Financial & Digital Regulation: DORA | Operational Resilience | ICT Third-Party Risk | T+1 Settlement]
    #v(8.4pt)
    #cv-b[AI & Data Governance: EU AI Act | Responsible AI | Model Risk | Human Oversight | Data Protection | GDPR]
    #cv-spacious-heading[Finance, Investments & Markets]
    #cv-h[Finance Transformation, Corporate Finance & M&A]
    #v(7.35pt)
    #cv-b[CFO Agenda: Finance Platform | Finance Data Architecture | Planning & Forecasting | AI-enabled Finance]
    #v(8.4pt)
    #cv-b[Corporate Finance: Financial Modelling | Valuation | DCF | Multiples | Project Finance | NPV | IRR | DSCR]
    #v(8.4pt)
    #cv-b[M&A: Target Screening | Financial Due Diligence | Synergy Assessment | Post-Merger Integration (PMI)]
    #cv-entry-gap()
    #cv-h[Private Markets & Investment Management]
    #v(7.35pt)
    #cv-b[Private Markets: Private Equity | Private Credit | Infrastructure Investments | Real Estate | Secondaries]
    #v(8.4pt)
    #cv-b[Investment Strategies: Buyouts | Growth Equity | Direct Lending | Distressed Debt | Special Situations]
    #v(8.4pt)
    #cv-b[CIO Office: Investment Strategy | Multi-Asset | Portfolio Construction | Strategic Asset Allocation (SAA)]
    #cv-entry-gap()
    #cv-h[Trading, Quantitative Finance & Risk]
    #v(7.35pt)
    #cv-b[Energy & Commodity Markets: Power Trading | Day-Ahead | Intraday | Gas/LNG | Metals | Carbon | Freight]
    #v(8.4pt)
    #cv-b[Systematic Trading: Alpha Signals | Backtesting | Trade Execution | Futures | Swaps | Options | Hedging]
    #v(8.4pt)
    #cv-b[Quantitative Risk: PnL | Value at Risk (VaR) | Stress Testing | Monte Carlo | Option Pricing | Volatility]
  ]
]

#assert-page-count(cv-pages)
