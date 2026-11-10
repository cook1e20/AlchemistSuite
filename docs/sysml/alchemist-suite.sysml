// Alchemist Suite: starter SysML v2 model (textual notation).
// Source of truth for the views in sequences.md. Built from CONTRACTS.md and issues/spec-*.md,
// not from the child repos' code. Checked clean with Spec42 (VS Code extension, v0.60.1).
// Note: 'new' is quoted because new is a SysML v2 keyword.

package AlchemistSuite {
    private import ScalarValues::*;

    // ---------------------------------------------------------------
    // Items: what flows between parts
    // ---------------------------------------------------------------
    package Items {
        item def DealsFeedRequest;
        item def DealBatch;
        item def ProductMatchQuery;
        item def ProductSignal;
        item def PricingFeesRequest;
        item def PricingFees;
        item def KeepaProductRequest;
        item def KeepaProduct;
        item def GatingRequest;
        item def GatingLabels;
        item def DealRecord;
        item def DealCard;
        item def BuyDecision;
        item def DismissDecision;
        item def CatalogueRequest;
        item def CatalogueFile;
        item def PriceHistoryUpdate;
        item def DropCandidate;
    }

    // ---------------------------------------------------------------
    // Structure: the systems and services (block definitions)
    // ---------------------------------------------------------------
    package Structure {
        private import Items::*;

        part def DealFinder { doc /* EU-to-UK deal probe, deal lifecycle, Discord cards. Repo: DealFinder. */ }
        part def AlchemistV2 { doc /* Catalogue miner, scheduler, Qogita drops, wholesale pre-screen. Repo: alchemist-v2. */ }
        part def Dashboard  { doc /* Browser UI on the anon key. Repo: Alchemist_Dashboard. */ }
        part def Supabase   { doc /* Shared Postgres, project A2ASearch. Tables per CONTRACTS.md section 2. */ }
        part def SqliteHistory { doc /* Qogita price_changes and price_summary on the VPS (spec Q17). */ }
        part def Keepa      { doc /* One shared token bucket (CONTRACTS.md section 5). */ }
        part def SpApi      { doc /* One seller account; pricing and fees split by time (ADR 0001). */ }
        part def KeepaCompanion { doc /* Chrome extension on Keepa Product Finder; writes asin_tracker. */ }
        part def QogitaApi;
        part def EanyIo { doc /* Supplier portal, automated pull planned (RUNLIST R55). */ }
        part def SupplierEmail { doc /* Zappies supplier emails, ingest planned (DealFinder). */ }
        part def BuySheet { doc /* Google Sheet of purchases: cost, qty, Seller SKU, date. Read by the analytics and import stages. */ }
        part def Discord;
        part def Operator;

        part suite {
            part dealFinder : DealFinder;
            part alchemist  : AlchemistV2;
            part dashboard  : Dashboard;
            part supabase   : Supabase;
            part sqlite     : SqliteHistory;
            part keepa      : Keepa;
            part spApi      : SpApi;
            part keepaCompanion : KeepaCompanion;
            part qogita     : QogitaApi;
            part eany       : EanyIo;
            part supplierEmail : SupplierEmail;
            part buySheet   : BuySheet;
            part discord    : Discord;
            part operator   : Operator;

            connect dealFinder to keepa;
            connect dealFinder to spApi;
            connect dealFinder to supabase;
            connect dealFinder to discord;
            connect alchemist to qogita;
            connect alchemist to sqlite;
            connect alchemist to supabase;
            connect alchemist to keepa;
            connect alchemist to spApi;
            connect alchemist to discord;
            connect alchemist to buySheet;
            connect alchemist to eany;
            connect dealFinder to supplierEmail;
            connect keepaCompanion to supabase;
            connect operator to buySheet;
            connect dashboard to supabase;
            connect operator to dashboard;
            connect discord to operator;
        }
    }

    // ---------------------------------------------------------------
    // Requirements: the cross-repo rules the diagrams must respect
    // ---------------------------------------------------------------
    package Requirements {
        private import Structure::*;

        requirement <'GOAL'> businessGoal {
            doc /* Track the business, and offer as many pre-filtered buy deals as possible,
                   so the inventory keeps rolling. Top of the requirement tree. */
            requirement <'GOAL-1'> trackBusiness {
                doc /* Finance and inventory state visible on the Dashboard, refreshed at least daily. */
            }
            requirement <'GOAL-2'> preFilteredDeals {
                doc /* Every deal shown to the operator has passed an automated ROI and velocity screen. */
            }
            requirement <'GOAL-3'> inventoryRolling {
                doc /* Every held item has a hold-or-sell verdict and a suggested price (RUNLIST R51). */
            }
        }

        requirement def TimeWindow {
            doc /* Calls happen only between startHour (inclusive) and endHour (exclusive), UK local time. */
            attribute startHour : Integer;
            attribute endHour : Integer;
        }

        requirement <'SPW-DF'> dealFinderSpApiWindow : TimeWindow {
            doc /* DealFinder owns SP-API competitive pricing and fees 08:00-20:00 UK (ADR 0001). */
            :>> startHour = 8;
            :>> endHour = 20;
        }
        requirement <'SPW-A2'> alchemistSpApiWindow : TimeWindow {
            doc /* alchemist-v2 owns SP-API competitive pricing and fees 20:00-08:00 UK (ADR 0001). */
            :>> startHour = 20;
            :>> endHour = 8;
        }
        requirement <'KW-A2'> minerKeepaWindow : TimeWindow {
            doc /* The alchemist-v2 miner owns Keepa 21:00-05:00 UK; DealFinder skips its tick then. */
            :>> startHour = 21;
            :>> endHour = 5;
        }
        requirement <'KEEPA-SERVER'> keepaServerSideOnly {
            doc /* Keepa token spend is server-side and schedule-gated. No dashboard action spends tokens. */
        }
        requirement <'QF-ROI'> qogitaFeedRoiFloor {
            doc /* A Qogita feed deal passes only if the lower of ROI at BB avg30 and BB avg90 is >= 20%
                   on gross cash cost (cost ex VAT x 1.2). Never on the current buy box. */
            attribute minRoi : Real = 0.20;
        }

        requirement <'ADR5'> discordUrgentOnly {
            doc /* Discord carries only urgent, perishable actions; everything else goes on a Dashboard tab (ADR 0005). */
        }
        requirement <'ADR4'> oneEconomics {
            doc /* Every evaluator uses the shared economics package and the settings table (ADR 0004). */
            attribute prepPencePerUnit : Integer = 100;
            attribute defaultMinRoi : Real = 0.20;
        }
        requirement <'ADR3'> oneSourcingPipeline {
            doc /* Every source writes candidates; DealFinder evaluates all of them (ADR 0003). */
        }

        satisfy oneSourcingPipeline by Structure::suite.dealFinder;
        satisfy dealFinderSpApiWindow by Structure::suite.dealFinder;
        satisfy alchemistSpApiWindow by Structure::suite.alchemist;
        satisfy minerKeepaWindow by Structure::suite.alchemist;
        satisfy keepaServerSideOnly by Structure::suite.dashboard;
        satisfy qogitaFeedRoiFloor by Structure::suite.dealFinder;
        satisfy businessGoal.trackBusiness by Structure::suite.dashboard;
        satisfy businessGoal.preFilteredDeals by Structure::suite.dealFinder;
        satisfy businessGoal.preFilteredDeals by Structure::suite.alchemist;
        satisfy businessGoal.inventoryRolling by Structure::suite.alchemist;
    }

    // ---------------------------------------------------------------
    // Behaviour: deal lifecycle (CONTRACTS.md, deals table)
    // ---------------------------------------------------------------
    package Lifecycle {
        private import Items::*;

        state def DealLifecycle {
            entry; then 'new';
            state 'new';
            state notified;
            state bought;
            state dismissed;

            transition notify first 'new' then notified;
            transition buyNew first 'new' accept BuyDecision then bought;
            transition dismissNew first 'new' accept DismissDecision then dismissed;
            transition buyNotified first notified accept BuyDecision then bought;
            transition dismissNotified first notified accept DismissDecision then dismissed;
        }

        // Target design (ADR 0002, issues/spec-business-loop.md): one lot per BuySheet row.
        item def UnitsAtAmazon;
        item def FirstSale;
        item def PaceAboveExpected;
        item def MarginalResult;
        item def UnaccountedAfter30Days;
        item def Found;
        item def LastUnitSold;

        state def LotLifecycle {
            entry; then inTransit;
            state inTransit;
            state flagged;
            state atAmazon;
            state selling;
            state winner;
            state marginal;
            state soldOut;

            transition first inTransit accept UnitsAtAmazon then atAmazon;
            transition first inTransit accept UnaccountedAfter30Days then flagged;
            transition first flagged accept Found then atAmazon;
            transition first atAmazon accept FirstSale then selling;
            transition first selling accept PaceAboveExpected then winner;
            transition first selling accept MarginalResult then marginal;
            transition first selling accept LastUnitSold then soldOut;
            transition first winner accept LastUnitSold then soldOut;
            transition first marginal accept LastUnitSold then soldOut;
        }
    }

    // ---------------------------------------------------------------
    // Interactions: the sequence diagrams. Each lifeline is a part with
    // ordered event occurrences; each arrow is a message between events.
    // ---------------------------------------------------------------
    package Interactions {
        private import Items::*;
        private import Structure::*;

        // View 1 in sequences.md: one day-time tick, main path.
        occurrence def DealFinderProbe {
            part dealFinder : DealFinder {
                event occurrence sendFeedRequest;
                then event occurrence receiveDeals;
                then event occurrence sendMatchQuery;
                then event occurrence receiveSignal;
                then event occurrence sendPricingRequest;
                then event occurrence receivePricing;
                then event occurrence sendKeepaRequest;
                then event occurrence receiveKeepa;
                then event occurrence sendGatingRequest;
                then event occurrence receiveGating;
                then event occurrence sendDealRecord;
                then event occurrence sendCard;
            }
            part keepa : Keepa {
                event occurrence receiveFeedRequest;
                then event occurrence sendDeals;
                then event occurrence receiveProductRequest;
                then event occurrence sendProduct;
            }
            part spApi : SpApi {
                event occurrence receivePricingRequest;
                then event occurrence sendPricing;
                then event occurrence receiveGatingRequest;
                then event occurrence sendGating;
            }
            part supabase : Supabase {
                event occurrence receiveMatchQuery;
                then event occurrence sendSignal;
                then event occurrence receiveDealRecord;
            }
            part discord : Discord {
                event occurrence receiveCard;
            }

            message feedRequest of DealsFeedRequest from dealFinder.sendFeedRequest to keepa.receiveFeedRequest;
            message deals of DealBatch from keepa.sendDeals to dealFinder.receiveDeals;
            message matchQuery of ProductMatchQuery from dealFinder.sendMatchQuery to supabase.receiveMatchQuery;
            message signal of ProductSignal from supabase.sendSignal to dealFinder.receiveSignal;
            message pricingRequest of PricingFeesRequest from dealFinder.sendPricingRequest to spApi.receivePricingRequest;
            message pricing of PricingFees from spApi.sendPricing to dealFinder.receivePricing;
            message productRequest of KeepaProductRequest from dealFinder.sendKeepaRequest to keepa.receiveProductRequest;
            message product of KeepaProduct from keepa.sendProduct to dealFinder.receiveKeepa;
            message gatingRequest of GatingRequest from dealFinder.sendGatingRequest to spApi.receiveGatingRequest;
            message gating of GatingLabels from spApi.sendGating to dealFinder.receiveGating;
            message dealRecord of DealRecord from dealFinder.sendDealRecord to supabase.receiveDealRecord;
            message card of DealCard from dealFinder.sendCard to discord.receiveCard;
        }

        // View 2 in sequences.md: one hourly Qogita pull with a new file, main path.
        occurrence def QogitaDropsPull {
            part alchemist : AlchemistV2 {
                event occurrence sendCatalogueRequest;
                then event occurrence receiveCatalogue;
                then event occurrence sendHistory;
                then event occurrence sendMatchQuery;
                then event occurrence receiveSignal;
                then event occurrence sendCandidates;
                then event occurrence sendCard;
            }
            part qogita : QogitaApi {
                event occurrence receiveCatalogueRequest;
                then event occurrence sendCatalogue;
            }
            part sqlite : SqliteHistory {
                event occurrence receiveHistory;
            }
            part supabase : Supabase {
                event occurrence receiveMatchQuery;
                then event occurrence sendSignal;
                then event occurrence receiveCandidates;
            }
            part discord : Discord {
                event occurrence receiveCard;
            }

            message catalogueRequest of CatalogueRequest from alchemist.sendCatalogueRequest to qogita.receiveCatalogueRequest;
            message catalogue of CatalogueFile from qogita.sendCatalogue to alchemist.receiveCatalogue;
            message history of PriceHistoryUpdate from alchemist.sendHistory to sqlite.receiveHistory;
            message matchQuery of ProductMatchQuery from alchemist.sendMatchQuery to supabase.receiveMatchQuery;
            message signal of ProductSignal from supabase.sendSignal to alchemist.receiveSignal;
            message candidates of DropCandidate from alchemist.sendCandidates to supabase.receiveCandidates;
            message card of DealCard from alchemist.sendCard to discord.receiveCard;
        }
    }

    // ---------------------------------------------------------------
    // Views: what Spec42's Views panel can draw. A view picks a view
    // definition (the diagram kind) and exposes the elements to show.
    // ---------------------------------------------------------------
    package Views {
        private import StandardViewDefinitions::*;

        view suiteStructure : GeneralView {
            doc /* The systems and services, and how they are typed. */
            expose AlchemistSuite::Structure::suite;
        }
        view suiteWiring : InterconnectionView {
            doc /* Who talks to whom: the connections inside suite. */
            expose AlchemistSuite::Structure::suite;
        }
        view dealLifecycle : StateTransitionView {
            doc /* Deal status: new, notified, bought, dismissed. */
            expose AlchemistSuite::Lifecycle::DealLifecycle;
        }
        view dealFinderProbe : SequenceView {
            doc /* View 1 in sequences.md: one DealFinder day-time tick. */
            expose AlchemistSuite::Interactions::DealFinderProbe;
        }
        view qogitaDropsPull : SequenceView {
            doc /* View 2 in sequences.md: one hourly Qogita pull. */
            expose AlchemistSuite::Interactions::QogitaDropsPull;
        }
    }
}
