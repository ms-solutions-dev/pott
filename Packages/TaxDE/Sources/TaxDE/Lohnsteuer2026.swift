// Generated from the BMF pseudocode Lohnsteuer2026.xml (version ?) by gen_pap.py.
// Do not edit by hand; regenerate when the BMF publishes a new year.
// swift-format-ignore-file

// The names follow the BMF program flow chart so the code can be compared with it line by line.
// swiftlint:disable all

struct Lohnsteuer2026 {
    // MARK: Inputs
    var af: Int = 1
    var AJAHR: Int = 0
    var ALTER1: Int = 0
    var ALV: Int = 0
    var f: Double = 1.0
    var JFREIB: BigDecimal = BigDecimal.zero
    var JHINZU: BigDecimal = BigDecimal.zero
    var JRE4: BigDecimal = BigDecimal.zero
    var JRE4ENT: BigDecimal = BigDecimal.zero
    var JVBEZ: BigDecimal = BigDecimal.zero
    var KRV: Int = 0
    var KVZ: BigDecimal = BigDecimal.zero
    var LZZ: Int = 1
    var LZZFREIB: BigDecimal = BigDecimal.zero
    var LZZHINZU: BigDecimal = BigDecimal.zero
    var MBV: BigDecimal = BigDecimal.zero
    var PKPV: BigDecimal = BigDecimal.zero
    var PKPVAGZ: BigDecimal = BigDecimal.zero
    var PKV: Int = 0
    var PVA: BigDecimal = BigDecimal.zero
    var PVS: Int = 0
    var PVZ: Int = 0
    var R: Int = 0
    var RE4: BigDecimal = BigDecimal.zero
    var SONSTB: BigDecimal = BigDecimal.zero
    var SONSTENT: BigDecimal = BigDecimal.zero
    var STERBE: BigDecimal = BigDecimal.zero
    var STKL: Int = 1
    var VBEZ: BigDecimal = BigDecimal.zero
    var VBEZM: BigDecimal = BigDecimal.zero
    var VBEZS: BigDecimal = BigDecimal.zero
    var VBS: BigDecimal = BigDecimal.zero
    var VJAHR: Int = 0
    var ZKF: BigDecimal = BigDecimal.zero
    var ZMVB: Int = 0

    // MARK: Outputs
    var BK: BigDecimal = BigDecimal.zero
    var BKS: BigDecimal = BigDecimal.zero
    var LSTLZZ: BigDecimal = BigDecimal.zero
    var SOLZLZZ: BigDecimal = BigDecimal.zero
    var SOLZS: BigDecimal = BigDecimal.zero
    var STS: BigDecimal = BigDecimal.zero
    var VFRB: BigDecimal = BigDecimal.zero
    var VFRBS1: BigDecimal = BigDecimal.zero
    var VFRBS2: BigDecimal = BigDecimal.zero
    var WVFRB: BigDecimal = BigDecimal.zero
    var WVFRBO: BigDecimal = BigDecimal.zero
    var WVFRBM: BigDecimal = BigDecimal.zero

    // MARK: Internals
    var ALTE: BigDecimal = BigDecimal.zero
    var ANP: BigDecimal = BigDecimal.zero
    var ANTEIL1: BigDecimal = BigDecimal.zero
    var AVSATZAN: BigDecimal = BigDecimal.zero
    var BBGKVPV: BigDecimal = BigDecimal.zero
    var BBGRVALV: BigDecimal = BigDecimal.zero
    var BMG: BigDecimal = BigDecimal.zero
    var DIFF: BigDecimal = BigDecimal.zero
    var EFA: BigDecimal = BigDecimal.zero
    var FVB: BigDecimal = BigDecimal.zero
    var FVBSO: BigDecimal = BigDecimal.zero
    var FVBZ: BigDecimal = BigDecimal.zero
    var FVBZSO: BigDecimal = BigDecimal.zero
    var GFB: BigDecimal = BigDecimal.zero
    var HBALTE: BigDecimal = BigDecimal.zero
    var HFVB: BigDecimal = BigDecimal.zero
    var HFVBZ: BigDecimal = BigDecimal.zero
    var HFVBZSO: BigDecimal = BigDecimal.zero
    var HOCH: BigDecimal = BigDecimal.zero
    var J: Int = 0
    var JBMG: BigDecimal = BigDecimal.zero
    var JLFREIB: BigDecimal = BigDecimal.zero
    var JLHINZU: BigDecimal = BigDecimal.zero
    var JW: BigDecimal = BigDecimal.zero
    var K: Int = 0
    var KFB: BigDecimal = BigDecimal.zero
    var KVSATZAN: BigDecimal = BigDecimal.zero
    var KZTAB: Int = 0
    var LSTJAHR: BigDecimal = BigDecimal.zero
    var LSTOSO: BigDecimal = BigDecimal.zero
    var LSTSO: BigDecimal = BigDecimal.zero
    var MIST: BigDecimal = BigDecimal.zero
    var PKPVAGZJ: BigDecimal = BigDecimal.zero
    var PVSATZAN: BigDecimal = BigDecimal.zero
    var RVSATZAN: BigDecimal = BigDecimal.zero
    var RW: BigDecimal = BigDecimal.zero
    var SAP: BigDecimal = BigDecimal.zero
    var SOLZFREI: BigDecimal = BigDecimal.zero
    var SOLZJ: BigDecimal = BigDecimal.zero
    var SOLZMIN: BigDecimal = BigDecimal.zero
    var SOLZSBMG: BigDecimal = BigDecimal.zero
    var SOLZSZVE: BigDecimal = BigDecimal.zero
    var ST: BigDecimal = BigDecimal.zero
    var ST1: BigDecimal = BigDecimal.zero
    var ST2: BigDecimal = BigDecimal.zero
    var VBEZB: BigDecimal = BigDecimal.zero
    var VBEZBSO: BigDecimal = BigDecimal.zero
    var VERGL: BigDecimal = BigDecimal.zero
    var VSPHB: BigDecimal = BigDecimal.zero
    var VSP: BigDecimal = BigDecimal.zero
    var VSPN: BigDecimal = BigDecimal.zero
    var VSPALV: BigDecimal = BigDecimal.zero
    var VSPKVPV: BigDecimal = BigDecimal.zero
    var VSPR: BigDecimal = BigDecimal.zero
    var W1STKL5: BigDecimal = BigDecimal.zero
    var W2STKL5: BigDecimal = BigDecimal.zero
    var W3STKL5: BigDecimal = BigDecimal.zero
    var X: BigDecimal = BigDecimal.zero
    var Y: BigDecimal = BigDecimal.zero
    var ZRE4: BigDecimal = BigDecimal.zero
    var ZRE4J: BigDecimal = BigDecimal.zero
    var ZRE4VP: BigDecimal = BigDecimal.zero
    var ZRE4VPR: BigDecimal = BigDecimal.zero
    var ZTABFB: BigDecimal = BigDecimal.zero
    var ZVBEZ: BigDecimal = BigDecimal.zero
    var ZVBEZJ: BigDecimal = BigDecimal.zero
    var ZVE: BigDecimal = BigDecimal.zero
    var ZX: BigDecimal = BigDecimal.zero
    var ZZX: BigDecimal = BigDecimal.zero

    // MARK: Constants
    let TAB1: [BigDecimal] = [BigDecimal.zero, BigDecimal(literal: "0.4"), BigDecimal(literal: "0.384"), BigDecimal(literal: "0.368"), BigDecimal(literal: "0.352"), BigDecimal(literal: "0.336"), BigDecimal(literal: "0.32"), BigDecimal(literal: "0.304"), BigDecimal(literal: "0.288"), BigDecimal(literal: "0.272"), BigDecimal(literal: "0.256"), BigDecimal(literal: "0.24"), BigDecimal(literal: "0.224"), BigDecimal(literal: "0.208"), BigDecimal(literal: "0.192"), BigDecimal(literal: "0.176"), BigDecimal(literal: "0.16"), BigDecimal(literal: "0.152"), BigDecimal(literal: "0.144"), BigDecimal(literal: "0.14"), BigDecimal(literal: "0.136"), BigDecimal(literal: "0.132"), BigDecimal(literal: "0.128"), BigDecimal(literal: "0.124"), BigDecimal(literal: "0.12"), BigDecimal(literal: "0.116"), BigDecimal(literal: "0.112"), BigDecimal(literal: "0.108"), BigDecimal(literal: "0.104"), BigDecimal(literal: "0.1"), BigDecimal(literal: "0.096"), BigDecimal(literal: "0.092"), BigDecimal(literal: "0.088"), BigDecimal(literal: "0.084"), BigDecimal(literal: "0.08"), BigDecimal(literal: "0.076"), BigDecimal(literal: "0.072"), BigDecimal(literal: "0.068"), BigDecimal(literal: "0.064"), BigDecimal(literal: "0.06"), BigDecimal(literal: "0.056"), BigDecimal(literal: "0.052"), BigDecimal(literal: "0.048"), BigDecimal(literal: "0.044"), BigDecimal(literal: "0.04"), BigDecimal(literal: "0.036"), BigDecimal(literal: "0.032"), BigDecimal(literal: "0.028"), BigDecimal(literal: "0.024"), BigDecimal(literal: "0.02"), BigDecimal(literal: "0.016"), BigDecimal(literal: "0.012"), BigDecimal(literal: "0.008"), BigDecimal(literal: "0.004"), BigDecimal(literal: "0")]
    let TAB2: [BigDecimal] = [BigDecimal.zero, BigDecimal(literal: "3000"), BigDecimal(literal: "2880"), BigDecimal(literal: "2760"), BigDecimal(literal: "2640"), BigDecimal(literal: "2520"), BigDecimal(literal: "2400"), BigDecimal(literal: "2280"), BigDecimal(literal: "2160"), BigDecimal(literal: "2040"), BigDecimal(literal: "1920"), BigDecimal(literal: "1800"), BigDecimal(literal: "1680"), BigDecimal(literal: "1560"), BigDecimal(literal: "1440"), BigDecimal(literal: "1320"), BigDecimal(literal: "1200"), BigDecimal(literal: "1140"), BigDecimal(literal: "1080"), BigDecimal(literal: "1050"), BigDecimal(literal: "1020"), BigDecimal(literal: "990"), BigDecimal(literal: "960"), BigDecimal(literal: "930"), BigDecimal(literal: "900"), BigDecimal(literal: "870"), BigDecimal(literal: "840"), BigDecimal(literal: "810"), BigDecimal(literal: "780"), BigDecimal(literal: "750"), BigDecimal(literal: "720"), BigDecimal(literal: "690"), BigDecimal(literal: "660"), BigDecimal(literal: "630"), BigDecimal(literal: "600"), BigDecimal(literal: "570"), BigDecimal(literal: "540"), BigDecimal(literal: "510"), BigDecimal(literal: "480"), BigDecimal(literal: "450"), BigDecimal(literal: "420"), BigDecimal(literal: "390"), BigDecimal(literal: "360"), BigDecimal(literal: "330"), BigDecimal(literal: "300"), BigDecimal(literal: "270"), BigDecimal(literal: "240"), BigDecimal(literal: "210"), BigDecimal(literal: "180"), BigDecimal(literal: "150"), BigDecimal(literal: "120"), BigDecimal(literal: "90"), BigDecimal(literal: "60"), BigDecimal(literal: "30"), BigDecimal(literal: "0")]
    let TAB3: [BigDecimal] = [BigDecimal.zero, BigDecimal(literal: "900"), BigDecimal(literal: "864"), BigDecimal(literal: "828"), BigDecimal(literal: "792"), BigDecimal(literal: "756"), BigDecimal(literal: "720"), BigDecimal(literal: "684"), BigDecimal(literal: "648"), BigDecimal(literal: "612"), BigDecimal(literal: "576"), BigDecimal(literal: "540"), BigDecimal(literal: "504"), BigDecimal(literal: "468"), BigDecimal(literal: "432"), BigDecimal(literal: "396"), BigDecimal(literal: "360"), BigDecimal(literal: "342"), BigDecimal(literal: "324"), BigDecimal(literal: "315"), BigDecimal(literal: "306"), BigDecimal(literal: "297"), BigDecimal(literal: "288"), BigDecimal(literal: "279"), BigDecimal(literal: "270"), BigDecimal(literal: "261"), BigDecimal(literal: "252"), BigDecimal(literal: "243"), BigDecimal(literal: "234"), BigDecimal(literal: "225"), BigDecimal(literal: "216"), BigDecimal(literal: "207"), BigDecimal(literal: "198"), BigDecimal(literal: "189"), BigDecimal(literal: "180"), BigDecimal(literal: "171"), BigDecimal(literal: "162"), BigDecimal(literal: "153"), BigDecimal(literal: "144"), BigDecimal(literal: "135"), BigDecimal(literal: "126"), BigDecimal(literal: "117"), BigDecimal(literal: "108"), BigDecimal(literal: "99"), BigDecimal(literal: "90"), BigDecimal(literal: "81"), BigDecimal(literal: "72"), BigDecimal(literal: "63"), BigDecimal(literal: "54"), BigDecimal(literal: "45"), BigDecimal(literal: "36"), BigDecimal(literal: "27"), BigDecimal(literal: "18"), BigDecimal(literal: "9"), BigDecimal(literal: "0")]
    let TAB4: [BigDecimal] = [BigDecimal.zero, BigDecimal(literal: "0.4"), BigDecimal(literal: "0.384"), BigDecimal(literal: "0.368"), BigDecimal(literal: "0.352"), BigDecimal(literal: "0.336"), BigDecimal(literal: "0.32"), BigDecimal(literal: "0.304"), BigDecimal(literal: "0.288"), BigDecimal(literal: "0.272"), BigDecimal(literal: "0.256"), BigDecimal(literal: "0.24"), BigDecimal(literal: "0.224"), BigDecimal(literal: "0.208"), BigDecimal(literal: "0.192"), BigDecimal(literal: "0.176"), BigDecimal(literal: "0.16"), BigDecimal(literal: "0.152"), BigDecimal(literal: "0.144"), BigDecimal(literal: "0.14"), BigDecimal(literal: "0.136"), BigDecimal(literal: "0.132"), BigDecimal(literal: "0.128"), BigDecimal(literal: "0.124"), BigDecimal(literal: "0.12"), BigDecimal(literal: "0.116"), BigDecimal(literal: "0.112"), BigDecimal(literal: "0.108"), BigDecimal(literal: "0.104"), BigDecimal(literal: "0.1"), BigDecimal(literal: "0.096"), BigDecimal(literal: "0.092"), BigDecimal(literal: "0.088"), BigDecimal(literal: "0.084"), BigDecimal(literal: "0.08"), BigDecimal(literal: "0.076"), BigDecimal(literal: "0.072"), BigDecimal(literal: "0.068"), BigDecimal(literal: "0.064"), BigDecimal(literal: "0.06"), BigDecimal(literal: "0.056"), BigDecimal(literal: "0.052"), BigDecimal(literal: "0.048"), BigDecimal(literal: "0.044"), BigDecimal(literal: "0.04"), BigDecimal(literal: "0.036"), BigDecimal(literal: "0.032"), BigDecimal(literal: "0.028"), BigDecimal(literal: "0.024"), BigDecimal(literal: "0.02"), BigDecimal(literal: "0.016"), BigDecimal(literal: "0.012"), BigDecimal(literal: "0.008"), BigDecimal(literal: "0.004"), BigDecimal(literal: "0")]
    let TAB5: [BigDecimal] = [BigDecimal.zero, BigDecimal(literal: "1900"), BigDecimal(literal: "1824"), BigDecimal(literal: "1748"), BigDecimal(literal: "1672"), BigDecimal(literal: "1596"), BigDecimal(literal: "1520"), BigDecimal(literal: "1444"), BigDecimal(literal: "1368"), BigDecimal(literal: "1292"), BigDecimal(literal: "1216"), BigDecimal(literal: "1140"), BigDecimal(literal: "1064"), BigDecimal(literal: "988"), BigDecimal(literal: "912"), BigDecimal(literal: "836"), BigDecimal(literal: "760"), BigDecimal(literal: "722"), BigDecimal(literal: "684"), BigDecimal(literal: "665"), BigDecimal(literal: "646"), BigDecimal(literal: "627"), BigDecimal(literal: "608"), BigDecimal(literal: "589"), BigDecimal(literal: "570"), BigDecimal(literal: "551"), BigDecimal(literal: "532"), BigDecimal(literal: "513"), BigDecimal(literal: "494"), BigDecimal(literal: "475"), BigDecimal(literal: "456"), BigDecimal(literal: "437"), BigDecimal(literal: "418"), BigDecimal(literal: "399"), BigDecimal(literal: "380"), BigDecimal(literal: "361"), BigDecimal(literal: "342"), BigDecimal(literal: "323"), BigDecimal(literal: "304"), BigDecimal(literal: "285"), BigDecimal(literal: "266"), BigDecimal(literal: "247"), BigDecimal(literal: "228"), BigDecimal(literal: "209"), BigDecimal(literal: "190"), BigDecimal(literal: "171"), BigDecimal(literal: "152"), BigDecimal(literal: "133"), BigDecimal(literal: "114"), BigDecimal(literal: "95"), BigDecimal(literal: "76"), BigDecimal(literal: "57"), BigDecimal(literal: "38"), BigDecimal(literal: "19"), BigDecimal(literal: "0")]
    let ZAHL1: BigDecimal = BigDecimal.one
    let ZAHL2: BigDecimal = BigDecimal(literal: "2")
    let ZAHL5: BigDecimal = BigDecimal(literal: "5")
    let ZAHL7: BigDecimal = BigDecimal(literal: "7")
    let ZAHL12: BigDecimal = BigDecimal(literal: "12")
    let ZAHL100: BigDecimal = BigDecimal(literal: "100")
    let ZAHL360: BigDecimal = BigDecimal(literal: "360")
    let ZAHL500: BigDecimal = BigDecimal(literal: "500")
    let ZAHL700: BigDecimal = BigDecimal(literal: "700")
    let ZAHL1000: BigDecimal = BigDecimal(literal: "1000")
    let ZAHL10000: BigDecimal = BigDecimal(literal: "10000")

    /// Runs the whole calculation; read the outputs afterwards.
    mutating func main() {
        MPARA()
        MRE4JL()
        VBEZBSO = BigDecimal.zero
        MRE4()
        MRE4ABZ()
        MBERECH()
        MSONST()
    }

    mutating func MPARA() {
        BBGRVALV = BigDecimal(literal: "101400")
        AVSATZAN = BigDecimal(literal: "0.013")
        RVSATZAN = BigDecimal(literal: "0.093")
        BBGKVPV = BigDecimal(literal: "69750")
        KVSATZAN = (KVZ.divide(ZAHL2).divide(ZAHL100)).add(BigDecimal(literal: "0.07"))
        if PVS == 1 {
            PVSATZAN = BigDecimal(literal: "0.023")
        } else {
            PVSATZAN = BigDecimal(literal: "0.018")
        }
        if PVZ == 1 {
            PVSATZAN = PVSATZAN.add(BigDecimal(literal: "0.006"))
        } else {
            PVSATZAN = PVSATZAN.subtract(PVA.multiply(BigDecimal(literal: "0.0025")))
        }
        W1STKL5 = BigDecimal(literal: "14071")
        W2STKL5 = BigDecimal(literal: "34939")
        W3STKL5 = BigDecimal(literal: "222260")
        GFB = BigDecimal(literal: "12348")
        SOLZFREI = BigDecimal(literal: "20350")
    }

    mutating func MRE4JL() {
        if LZZ == 1 {
            ZRE4J = RE4.divide(ZAHL100, 2, .roundDown)
            ZVBEZJ = VBEZ.divide(ZAHL100, 2, .roundDown)
            JLFREIB = LZZFREIB.divide(ZAHL100, 2, .roundDown)
            JLHINZU = LZZHINZU.divide(ZAHL100, 2, .roundDown)
        } else {
            if LZZ == 2 {
                ZRE4J = (RE4.multiply(ZAHL12)).divide(ZAHL100, 2, .roundDown)
                ZVBEZJ = (VBEZ.multiply(ZAHL12)).divide(ZAHL100, 2, .roundDown)
                JLFREIB = (LZZFREIB.multiply(ZAHL12)).divide(ZAHL100, 2, .roundDown)
                JLHINZU = (LZZHINZU.multiply(ZAHL12)).divide(ZAHL100, 2, .roundDown)
            } else {
                if LZZ == 3 {
                    ZRE4J = (RE4.multiply(ZAHL360)).divide(ZAHL700, 2, .roundDown)
                    ZVBEZJ = (VBEZ.multiply(ZAHL360)).divide(ZAHL700, 2, .roundDown)
                    JLFREIB = (LZZFREIB.multiply(ZAHL360)).divide(ZAHL700, 2, .roundDown)
                    JLHINZU = (LZZHINZU.multiply(ZAHL360)).divide(ZAHL700, 2, .roundDown)
                } else {
                    ZRE4J = (RE4.multiply(ZAHL360)).divide(ZAHL100, 2, .roundDown)
                    ZVBEZJ = (VBEZ.multiply(ZAHL360)).divide(ZAHL100, 2, .roundDown)
                    JLFREIB = (LZZFREIB.multiply(ZAHL360)).divide(ZAHL100, 2, .roundDown)
                    JLHINZU = (LZZHINZU.multiply(ZAHL360)).divide(ZAHL100, 2, .roundDown)
                }
            }
        }
        if af == 0 {
            f = 1
        }
    }

    mutating func MRE4() {
        if ZVBEZJ.compareTo(BigDecimal.zero) == 0 {
            FVBZ = BigDecimal.zero
            FVB = BigDecimal.zero
            FVBZSO = BigDecimal.zero
            FVBSO = BigDecimal.zero
        } else {
            if VJAHR < 2006 {
                J = 1
            } else {
                if VJAHR < 2058 {
                    J = VJAHR - 2004
                } else {
                    J = 54
                }
            }
            if LZZ == 1 {
                VBEZB = (VBEZM.multiply(BigDecimal.valueOf(ZMVB))).add(VBEZS)
                HFVB = TAB2[J].divide(ZAHL12).multiply(BigDecimal.valueOf(ZMVB)).setScale(0, .roundUp)
                FVBZ = TAB3[J].divide(ZAHL12).multiply(BigDecimal.valueOf(ZMVB)).setScale(0, .roundUp)
            } else {
                VBEZB = ((VBEZM.multiply(ZAHL12)).add(VBEZS)).setScale(2, .roundDown)
                HFVB = TAB2[J]
                FVBZ = TAB3[J]
            }
            FVB = ((VBEZB.multiply(TAB1[J]))).divide(ZAHL100).setScale(2, .roundUp)
            if FVB.compareTo(HFVB) == 1 {
                FVB = HFVB
            }
            if FVB.compareTo(ZVBEZJ) == 1 {
                FVB = ZVBEZJ
            }
            FVBSO = (FVB.add((VBEZBSO.multiply(TAB1[J])).divide(ZAHL100))).setScale(2, .roundUp)
            if FVBSO.compareTo(TAB2[J]) == 1 {
                FVBSO = TAB2[J]
            }
            HFVBZSO = (((VBEZB.add(VBEZBSO)).divide(ZAHL100)).subtract(FVBSO)).setScale(2, .roundDown)
            FVBZSO = (FVBZ.add((VBEZBSO).divide(ZAHL100))).setScale(0, .roundUp)
            if FVBZSO.compareTo(HFVBZSO) == 1 {
                FVBZSO = HFVBZSO.setScale(0, .roundUp)
            }
            if FVBZSO.compareTo(TAB3[J]) == 1 {
                FVBZSO = TAB3[J]
            }
            HFVBZ = ((VBEZB.divide(ZAHL100)).subtract(FVB)).setScale(2, .roundDown)
            if FVBZ.compareTo(HFVBZ) == 1 {
                FVBZ = HFVBZ.setScale(0, .roundUp)
            }
        }
        MRE4ALTE()
    }

    mutating func MRE4ALTE() {
        if ALTER1 == 0 {
            ALTE = BigDecimal.zero
        } else {
            if AJAHR < 2006 {
                K = 1
            } else {
                if AJAHR < 2058 {
                    K = AJAHR - 2004
                } else {
                    K = 54
                }
            }
            BMG = ZRE4J.subtract(ZVBEZJ)
            ALTE = (BMG.multiply(TAB4[K])).setScale(0, .roundUp)
            HBALTE = TAB5[K]
            if ALTE.compareTo(HBALTE) == 1 {
                ALTE = HBALTE
            }
        }
    }

    mutating func MRE4ABZ() {
        ZRE4 = (ZRE4J.subtract(FVB).subtract(ALTE).subtract(JLFREIB).add(JLHINZU)).setScale(2, .roundDown)
        if ZRE4.compareTo(BigDecimal.zero) == -1 {
            ZRE4 = BigDecimal.zero
        }
        ZRE4VP = ZRE4J
        ZVBEZ = ZVBEZJ.subtract(FVB).setScale(2, .roundDown)
        if ZVBEZ.compareTo(BigDecimal.zero) == -1 {
            ZVBEZ = BigDecimal.zero
        }
    }

    mutating func MBERECH() {
        MZTABFB()
        VFRB = ((ANP.add(FVB.add(FVBZ))).multiply(ZAHL100)).setScale(0, .roundDown)
        MLSTJAHR()
        WVFRB = ((ZVE.subtract(GFB)).multiply(ZAHL100)).setScale(0, .roundDown)
        if WVFRB.compareTo(BigDecimal.zero) == -1 {
            WVFRB = BigDecimal.zero
        }
        LSTJAHR = (ST.multiply(BigDecimal.valueOf(f))).setScale(0,.roundDown)
        UPLSTLZZ()
        if ZKF.compareTo(BigDecimal.zero) == 1 {
            ZTABFB = ZTABFB.add(KFB)
            MRE4ABZ()
            MLSTJAHR()
            JBMG = (ST.multiply(BigDecimal.valueOf(f))).setScale(0,.roundDown)
        } else {
            JBMG = LSTJAHR
        }
        MSOLZ()
    }

    mutating func MZTABFB() {
        ANP = BigDecimal.zero
        if ZVBEZ.compareTo(BigDecimal.zero) >= 0 && ZVBEZ.compareTo(FVBZ) == -1 {
            FVBZ = BigDecimal.valueOf(ZVBEZ.longValue())
        }
        if STKL < 6 {
            if ZVBEZ.compareTo(BigDecimal.zero) == 1 {
                if (ZVBEZ.subtract(FVBZ)).compareTo(BigDecimal(literal: "102")) == -1 {
                    ANP = (ZVBEZ.subtract(FVBZ)).setScale(0, .roundUp)
                } else {
                    ANP = BigDecimal(literal: "102")
                }
            }
        } else {
            FVBZ = BigDecimal.zero
            FVBZSO = BigDecimal.zero
        }
        if STKL < 6 {
            if ZRE4.compareTo(ZVBEZ) == 1 {
                if ZRE4.subtract(ZVBEZ).compareTo(BigDecimal(literal: "1230")) == -1 {
                    ANP = ANP.add(ZRE4).subtract(ZVBEZ).setScale(0,.roundUp)
                } else {
                    ANP = ANP.add(BigDecimal(literal: "1230"))
                }
            }
        }
        KZTAB = 1
        if STKL == 1 {
            SAP = BigDecimal(literal: "36")
            KFB = (ZKF.multiply(BigDecimal(literal: "9756"))).setScale(0, .roundDown)
        } else {
            if STKL == 2 {
                EFA = BigDecimal(literal: "4260")
                SAP = BigDecimal(literal: "36")
                KFB = (ZKF.multiply(BigDecimal(literal: "9756"))).setScale(0, .roundDown)
            } else {
                if STKL == 3 {
                    KZTAB = 2
                    SAP = BigDecimal(literal: "36")
                    KFB = (ZKF.multiply(BigDecimal(literal: "9756"))).setScale(0, .roundDown)
                } else {
                    if STKL == 4 {
                        SAP = BigDecimal(literal: "36")
                        KFB = (ZKF.multiply(BigDecimal(literal: "4878"))).setScale(0, .roundDown)
                    } else {
                        if STKL == 5 {
                            SAP = BigDecimal(literal: "36")
                            KFB = BigDecimal.zero
                        } else {
                            KFB = BigDecimal.zero
                        }
                    }
                }
            }
        }
        ZTABFB = (EFA.add(ANP).add(SAP).add(FVBZ)).setScale(2, .roundDown)
    }

    mutating func MLSTJAHR() {
        UPEVP()
        ZVE = ZRE4.subtract(ZTABFB).subtract(VSP)
        UPMLST()
    }

    mutating func UPLSTLZZ() {
        JW = LSTJAHR.multiply(ZAHL100)
        UPANTEIL()
        LSTLZZ = ANTEIL1
    }

    mutating func UPMLST() {
        if ZVE.compareTo(ZAHL1) == -1 {
            ZVE = BigDecimal.zero
            X = BigDecimal.zero
        } else {
            X = (ZVE.divide(BigDecimal.valueOf(KZTAB))).setScale(0, .roundDown)
        }
        if STKL < 5 {
            UPTAB26()
        } else {
            MST5_6()
        }
    }

    mutating func UPEVP() {
        if KRV == 1 {
            VSPR = BigDecimal.zero
        } else {
            if ZRE4VP.compareTo(BBGRVALV) == 1 {
                ZRE4VPR = BBGRVALV
            } else {
                ZRE4VPR = ZRE4VP
            }
            VSPR = (ZRE4VPR.multiply(RVSATZAN)).setScale(2,.roundDown)
        }
        MVSPKVPV()
        if ALV == 1 {
        } else {
            if STKL == 6 {
            } else {
                MVSPHB()
            }
        }
    }

    mutating func MVSPKVPV() {
        if ZRE4VP.compareTo(BBGKVPV) == 1 {
            ZRE4VPR = BBGKVPV
        } else {
            ZRE4VPR = ZRE4VP
        }
        if PKV > 0 {
            if STKL == 6 {
                VSPKVPV = BigDecimal.zero
            } else {
                PKPVAGZJ = PKPVAGZ.multiply(ZAHL12).divide(ZAHL100).setScale(2,.roundDown)
                VSPKVPV = PKPV.multiply(ZAHL12).divide(ZAHL100).setScale(2, .roundDown)
                VSPKVPV = VSPKVPV.subtract(PKPVAGZJ)
                if VSPKVPV.compareTo(BigDecimal.zero) == -1 {
                    VSPKVPV = BigDecimal.zero
                }
            }
        } else {
            VSPKVPV = ZRE4VPR.multiply(KVSATZAN.add(PVSATZAN)).setScale(2, .roundDown)
        }
        VSP = VSPKVPV.add(VSPR).setScale(0, .roundUp)
    }

    mutating func MVSPHB() {
        if ZRE4VP.compareTo(BBGRVALV) == 1 {
            ZRE4VPR = BBGRVALV
        } else {
            ZRE4VPR = ZRE4VP
        }
        VSPALV = AVSATZAN.multiply(ZRE4VPR).setScale(2, .roundDown)
        VSPHB = VSPALV.add(VSPKVPV).setScale(2, .roundDown)
        if VSPHB.compareTo(BigDecimal(literal: "1900")) == 1 {
            VSPHB = BigDecimal(literal: "1900")
        }
        VSPN = VSPR.add(VSPHB).setScale(0, .roundUp)
        if VSPN.compareTo(VSP) == 1 {
            VSP = VSPN
        }
    }

    mutating func MST5_6() {
        ZZX = X
        if ZZX.compareTo(W2STKL5) == 1 {
            ZX = W2STKL5
            UP5_6()
            if ZZX.compareTo(W3STKL5) == 1 {
                ST = (ST.add((W3STKL5.subtract(W2STKL5)).multiply(BigDecimal(literal: "0.42")))).setScale(0, .roundDown)
                ST = (ST.add((ZZX.subtract(W3STKL5)).multiply(BigDecimal(literal: "0.45")))).setScale(0, .roundDown)
            } else {
                ST = (ST.add((ZZX.subtract(W2STKL5)).multiply(BigDecimal(literal: "0.42")))).setScale(0, .roundDown)
            }
        } else {
            ZX = ZZX
            UP5_6()
            if ZZX.compareTo(W1STKL5) == 1 {
                VERGL = ST
                ZX = W1STKL5
                UP5_6()
                HOCH = (ST.add((ZZX.subtract(W1STKL5)).multiply(BigDecimal(literal: "0.42")))).setScale(0, .roundDown)
                if HOCH.compareTo(VERGL) == -1 {
                    ST = HOCH
                } else {
                    ST = VERGL
                }
            }
        }
    }

    mutating func UP5_6() {
        X = (ZX.multiply(BigDecimal(literal: "1.25"))).setScale(0, .roundDown)
        UPTAB26()
        ST1 = ST
        X = (ZX.multiply(BigDecimal(literal: "0.75"))).setScale(0, .roundDown)
        UPTAB26()
        ST2 = ST
        DIFF = (ST1.subtract(ST2)).multiply(ZAHL2)
        MIST = (ZX.multiply(BigDecimal(literal: "0.14"))).setScale(0, .roundDown)
        if MIST.compareTo(DIFF) == 1 {
            ST = MIST
        } else {
            ST = DIFF
        }
    }

    mutating func MSOLZ() {
        SOLZFREI = (SOLZFREI.multiply(BigDecimal.valueOf(KZTAB)))
        if JBMG.compareTo(SOLZFREI) == 1 {
            SOLZJ = (JBMG.multiply(BigDecimal(literal: "5.5"))).divide(ZAHL100).setScale(2, .roundDown)
            SOLZMIN = (JBMG.subtract(SOLZFREI)).multiply(BigDecimal(literal: "11.9")).divide(ZAHL100).setScale(2, .roundDown)
            if SOLZMIN.compareTo(SOLZJ) == -1 {
                SOLZJ = SOLZMIN
            }
            JW = SOLZJ.multiply(ZAHL100).setScale(0, .roundDown)
            UPANTEIL()
            SOLZLZZ = ANTEIL1
        } else {
            SOLZLZZ = BigDecimal.zero
        }
        if R > 0 {
            JW = JBMG.multiply(ZAHL100)
            UPANTEIL()
            BK = ANTEIL1
        } else {
            BK = BigDecimal.zero
        }
    }

    mutating func UPANTEIL() {
        if LZZ == 1 {
            ANTEIL1 = JW
        } else {
            if LZZ == 2 {
                ANTEIL1 = JW.divide(ZAHL12, 0, .roundDown)
            } else {
                if LZZ == 3 {
                    ANTEIL1 = (JW.multiply(ZAHL7)).divide(ZAHL360, 0, .roundDown)
                } else {
                    ANTEIL1 = JW.divide(ZAHL360, 0, .roundDown)
                }
            }
        }
    }

    mutating func MSONST() {
        LZZ = 1
        if ZMVB == 0 {
            ZMVB = 12
        }
        if SONSTB.compareTo(BigDecimal.zero) == 0 && MBV.compareTo(BigDecimal.zero) == 0 {
            LSTSO = BigDecimal.zero
            STS = BigDecimal.zero
            SOLZS = BigDecimal.zero
            BKS = BigDecimal.zero
        } else {
            MOSONST()
            ZRE4J = ((JRE4.add(SONSTB)).divide(ZAHL100)).setScale(2, .roundDown)
            ZVBEZJ = ((JVBEZ.add(VBS)).divide(ZAHL100)).setScale(2, .roundDown)
            VBEZBSO = STERBE
            MRE4SONST()
            MLSTJAHR()
            WVFRBM = (ZVE.subtract(GFB)).multiply(ZAHL100).setScale(2,.roundDown)
            if WVFRBM.compareTo(BigDecimal.zero) == -1 {
                WVFRBM = BigDecimal.zero
            }
            LSTSO = ST.multiply(ZAHL100)
            STS = LSTSO.subtract(LSTOSO).multiply(BigDecimal.valueOf(f)).divide(ZAHL100, 0, .roundDown).multiply(ZAHL100)
            STSMIN()
        }
    }

    mutating func STSMIN() {
        if STS.compareTo(BigDecimal.zero) == -1 {
            if MBV.compareTo(BigDecimal.zero) == 0 {
            } else {
                LSTLZZ = LSTLZZ.add(STS)
                if LSTLZZ.compareTo(BigDecimal.zero) == -1 {
                    LSTLZZ = BigDecimal.zero
                }
                SOLZLZZ = SOLZLZZ.add(STS.multiply(BigDecimal(literal: "5.5").divide(ZAHL100))).setScale(0, .roundDown)
                if SOLZLZZ.compareTo(BigDecimal.zero) == -1 {
                    SOLZLZZ = BigDecimal.zero
                }
                BK = BK.add(STS)
                if BK.compareTo(BigDecimal.zero) == -1 {
                    BK = BigDecimal.zero
                }
            }
            STS = BigDecimal.zero
            SOLZS = BigDecimal.zero
        } else {
            MSOLZSTS()
        }
        if R > 0 {
            BKS = STS
        } else {
            BKS = BigDecimal.zero
        }
    }

    mutating func MSOLZSTS() {
        if ZKF.compareTo(BigDecimal.zero) == 1 {
            SOLZSZVE = ZVE.subtract(KFB)
        } else {
            SOLZSZVE = ZVE
        }
        if SOLZSZVE.compareTo(BigDecimal.one) == -1 {
            SOLZSZVE = BigDecimal.zero
            X = BigDecimal.zero
        } else {
            X = SOLZSZVE.divide(BigDecimal.valueOf(KZTAB), 0, .roundDown)
        }
        if STKL < 5 {
            UPTAB26()
        } else {
            MST5_6()
        }
        SOLZSBMG = ST.multiply(BigDecimal.valueOf(f)).setScale(0,.roundDown)
        if SOLZSBMG.compareTo(SOLZFREI) == 1 {
            SOLZS = STS.multiply(BigDecimal(literal: "5.5")).divide(ZAHL100, 0, .roundDown)
        } else {
            SOLZS = BigDecimal.zero
        }
    }

    mutating func MOSONST() {
        ZRE4J = (JRE4.divide(ZAHL100)).setScale(2, .roundDown)
        ZVBEZJ = (JVBEZ.divide(ZAHL100)).setScale(2, .roundDown)
        JLFREIB = JFREIB.divide(ZAHL100, 2, .roundDown)
        JLHINZU = JHINZU.divide(ZAHL100, 2, .roundDown)
        MRE4()
        MRE4ABZ()
        ZRE4VP = ZRE4VP.subtract(JRE4ENT.divide(ZAHL100))
        MZTABFB()
        VFRBS1 = ((ANP.add(FVB.add(FVBZ))).multiply(ZAHL100)).setScale(2,.roundDown)
        MLSTJAHR()
        WVFRBO = ((ZVE.subtract(GFB)).multiply(ZAHL100)).setScale(2, .roundDown)
        if WVFRBO.compareTo(BigDecimal.zero) == -1 {
            WVFRBO = BigDecimal.zero
        }
        LSTOSO = ST.multiply(ZAHL100)
    }

    mutating func MRE4SONST() {
        MRE4()
        FVB = FVBSO
        MRE4ABZ()
        ZRE4VP = ZRE4VP.add(MBV.divide(ZAHL100)).subtract(JRE4ENT.divide(ZAHL100)).subtract(SONSTENT.divide(ZAHL100))
        FVBZ = FVBZSO
        MZTABFB()
        VFRBS2 = ((((ANP.add(FVB).add(FVBZ))).multiply(ZAHL100))).subtract(VFRBS1)
    }

    mutating func UPTAB26() {
        if X.compareTo(GFB.add(ZAHL1)) == -1 {
            ST = BigDecimal.zero
        } else {
            if X.compareTo(BigDecimal(literal: "17800")) == -1 {
                Y = (X.subtract(GFB)).divide(ZAHL10000, 6,.roundDown)
                RW = Y.multiply(BigDecimal(literal: "914.51"))
                RW = RW.add(BigDecimal(literal: "1400"))
                ST = (RW.multiply(Y)).setScale(0, .roundDown)
            } else {
                if X.compareTo(BigDecimal(literal: "69879")) == -1 {
                    Y = (X.subtract(BigDecimal(literal: "17799"))).divide(ZAHL10000, 6, .roundDown)
                    RW = Y.multiply(BigDecimal(literal: "173.1"))
                    RW = RW.add(BigDecimal(literal: "2397"))
                    RW = RW.multiply(Y)
                    ST = (RW.add(BigDecimal(literal: "1034.87"))).setScale(0, .roundDown)
                } else {
                    if X.compareTo(BigDecimal(literal: "277826")) == -1 {
                        ST = ((X.multiply(BigDecimal(literal: "0.42"))).subtract(BigDecimal(literal: "11135.63"))).setScale(0, .roundDown)
                    } else {
                        ST = ((X.multiply(BigDecimal(literal: "0.45"))).subtract(BigDecimal(literal: "19470.38"))).setScale(0, .roundDown)
                    }
                }
            }
        }
        ST = ST.multiply(BigDecimal.valueOf(KZTAB))
    }
}
