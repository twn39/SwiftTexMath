import Foundation

/// Command / symbol tables for LaTeX math (ported from iosMath / SwiftUIMath).
public enum AtomFactory {
    public static let aliases: [String: String] = [
        "lnot": "neg",
        "land": "wedge",
        "lor": "vee",
        "ne": "neq",
        "le": "leq",
        "ge": "geq",
        "lbrace": "{",
        "rbrace": "}",
        "Vert": "|",
        "gets": "leftarrow",
        "to": "rightarrow",
        "iff": "Longleftrightarrow",
        "AA": "angstrom",
    ]

    public static let delimiters: [String: String] = [
        ".": "",
        "(": "(",
        ")": ")",
        "[": "[",
        "]": "]",
        "<": "\u{2329}",
        ">": "\u{232A}",
        "/": "/",
        "\\": "\\",
        "|": "|",
        "lgroup": "\u{27EE}",
        "rgroup": "\u{27EF}",
        "||": "\u{2016}",
        "Vert": "\u{2016}",
        "vert": "|",
        "uparrow": "\u{2191}",
        "downarrow": "\u{2193}",
        "updownarrow": "\u{2195}",
        "Uparrow": "\u{21D1}",
        "Downarrow": "\u{21D3}",
        "Updownarrow": "\u{21D5}",
        "backslash": "\\",
        "rangle": "\u{232A}",
        "langle": "\u{2329}",
        "rbrace": "}",
        "}": "}",
        "{": "{",
        "lbrace": "{",
        "lceil": "\u{2308}",
        "rceil": "\u{2309}",
        "lfloor": "\u{230A}",
        "rfloor": "\u{230B}",
    ]

    public static let accents: [String: String] = [
        "grave": "\u{0300}",
        "acute": "\u{0301}",
        "hat": "\u{0302}",
        "tilde": "\u{0303}",
        "bar": "\u{0304}",
        "breve": "\u{0306}",
        "dot": "\u{0307}",
        "ddot": "\u{0308}",
        "check": "\u{030C}",
        "vec": "\u{20D7}",
        "widehat": "\u{0302}",
        "widetilde": "\u{0303}",
    ]

    public static let symbols: [String: MathAtom] = {
        var table: [String: MathAtom] = [:]

        func put(_ name: String, _ atom: MathAtom) {
            table[name] = atom
        }

        // Greek
        let greek: [(String, String)] = [
            ("alpha", "\u{03B1}"), ("beta", "\u{03B2}"), ("gamma", "\u{03B3}"),
            ("delta", "\u{03B4}"), ("varepsilon", "\u{03B5}"), ("zeta", "\u{03B6}"),
            ("eta", "\u{03B7}"), ("theta", "\u{03B8}"), ("iota", "\u{03B9}"),
            ("kappa", "\u{03BA}"), ("lambda", "\u{03BB}"), ("mu", "\u{03BC}"),
            ("nu", "\u{03BD}"), ("xi", "\u{03BE}"), ("omicron", "\u{03BF}"),
            ("pi", "\u{03C0}"), ("rho", "\u{03C1}"), ("sigma", "\u{03C3}"),
            ("tau", "\u{03C4}"), ("upsilon", "\u{03C5}"), ("varphi", "\u{03C6}"),
            ("chi", "\u{03C7}"), ("psi", "\u{03C8}"), ("omega", "\u{03C9}"),
            ("Gamma", "\u{0393}"), ("Delta", "\u{0394}"), ("Theta", "\u{0398}"),
            ("Lambda", "\u{039B}"), ("Xi", "\u{039E}"), ("Pi", "\u{03A0}"),
            ("Sigma", "\u{03A3}"), ("Upsilon", "\u{03A5}"), ("Phi", "\u{03A6}"),
            ("Psi", "\u{03A8}"), ("Omega", "\u{03A9}"),
        ]
        for (name, nucleus) in greek {
            put(name, .variable(nucleus))
        }
        put("epsilon", .ordinary("\u{1D716}"))
        put("vartheta", .ordinary("\u{1D717}"))
        put("phi", .ordinary("\u{1D719}"))
        put("varrho", .ordinary("\u{1D71A}"))
        put("varpi", .ordinary("\u{1D71B}"))

        // Delimiters as open/close
        put("lceil", .open("\u{2308}"))
        put("lfloor", .open("\u{230A}"))
        put("langle", .open("\u{27E8}"))
        put("lgroup", .open("\u{27EE}"))
        put("rceil", .close("\u{2309}"))
        put("rfloor", .close("\u{230B}"))
        put("rangle", .close("\u{27E9}"))
        put("rgroup", .close("\u{27EF}"))

        // Relations
        let relations: [(String, String)] = [
            ("leftarrow", "\u{2190}"), ("uparrow", "\u{2191}"), ("rightarrow", "\u{2192}"),
            ("downarrow", "\u{2193}"), ("leftrightarrow", "\u{2194}"), ("updownarrow", "\u{2195}"),
            ("mapsto", "\u{21A6}"), ("Leftarrow", "\u{21D0}"), ("Uparrow", "\u{21D1}"),
            ("Rightarrow", "\u{21D2}"), ("Downarrow", "\u{21D3}"), ("Leftrightarrow", "\u{21D4}"),
            ("longleftarrow", "\u{27F5}"), ("longrightarrow", "\u{27F6}"),
            ("longleftrightarrow", "\u{27F7}"), ("Longleftarrow", "\u{27F8}"),
            ("Longrightarrow", "\u{27F9}"), ("Longleftrightarrow", "\u{27FA}"),
            ("leq", "\u{2264}"), ("geq", "\u{2265}"), ("neq", "\u{2260}"),
            ("in", "\u{2208}"), ("notin", "\u{2209}"), ("ni", "\u{220B}"),
            ("propto", "\u{221D}"), ("mid", "\u{2223}"), ("parallel", "\u{2225}"),
            ("sim", "\u{223C}"), ("simeq", "\u{2243}"), ("cong", "\u{2245}"),
            ("approx", "\u{2248}"), ("equiv", "\u{2261}"), ("gg", "\u{226B}"), ("ll", "\u{226A}"),
            ("subset", "\u{2282}"), ("supset", "\u{2283}"),
            ("subseteq", "\u{2286}"), ("supseteq", "\u{2287}"),
            ("perp", "\u{27C2}"), ("implies", "\u{27F9}"),
        ]
        for (name, nucleus) in relations {
            put(name, .relation(nucleus))
        }

        // Binary operators
        let bins: [(String, String)] = [
            ("times", "\u{00D7}"), ("div", "\u{00F7}"), ("pm", "\u{00B1}"), ("mp", "\u{2213}"),
            ("setminus", "\u{2216}"), ("ast", "\u{2217}"), ("circ", "\u{2218}"),
            ("bullet", "\u{2219}"), ("wedge", "\u{2227}"), ("vee", "\u{2228}"),
            ("cap", "\u{2229}"), ("cup", "\u{222A}"), ("oplus", "\u{2295}"),
            ("ominus", "\u{2296}"), ("otimes", "\u{2297}"), ("oslash", "\u{2298}"),
            ("odot", "\u{2299}"), ("cdot", "\u{22C5}"), ("star", "\u{22C6}"),
        ]
        for (name, nucleus) in bins {
            put(name, .binaryOperator(nucleus))
        }

        // Named operators
        for name in ["log", "lg", "ln", "sin", "arcsin", "sinh", "cos", "arccos", "cosh",
                     "tan", "arctan", "tanh", "cot", "coth", "sec", "csc", "arg", "ker",
                     "dim", "hom", "exp", "deg", "mod"] {
            put(name, .largeOperator(name, limits: false))
        }
        for name in ["lim", "limsup", "liminf", "max", "min", "sup", "inf", "det", "Pr", "gcd"] {
            let nucleus = name == "limsup" ? "lim sup" : name == "liminf" ? "lim inf" : name
            put(name, .largeOperator(nucleus, limits: true))
        }

        put("prod", .largeOperator("\u{220F}", limits: true))
        put("coprod", .largeOperator("\u{2210}", limits: true))
        put("sum", .largeOperator("\u{2211}", limits: true))
        put("int", .largeOperator("\u{222B}", limits: false))
        put("iint", .largeOperator("\u{222C}", limits: false))
        put("iiint", .largeOperator("\u{222D}", limits: false))
        put("oint", .largeOperator("\u{222E}", limits: false))
        put("bigcap", .largeOperator("\u{22C2}", limits: true))
        put("bigcup", .largeOperator("\u{22C3}", limits: true))
        put("bigvee", .largeOperator("\u{22C1}", limits: true))
        put("bigwedge", .largeOperator("\u{22C0}", limits: true))

        // Literal escapes
        put("{", .open("{"))
        put("}", .close("}"))
        put("$", .ordinary("$"))
        put("&", .ordinary("&"))
        put("#", .ordinary("#"))
        put("%", .ordinary("%"))
        put("_", .ordinary("_"))
        put(" ", .ordinary(" "))
        put("backslash", .ordinary("\\"))
        put("|", .ordinary("\u{2016}"))
        put("vert", .ordinary("|"))

        // Misc
        put("colon", .punctuation(":"))
        put("infty", .ordinary("\u{221E}"))
        put("partial", .ordinary("\u{1D715}"))
        put("nabla", .ordinary("\u{2207}"))
        put("emptyset", .ordinary("\u{2205}"))
        put("forall", .ordinary("\u{2200}"))
        put("exists", .ordinary("\u{2203}"))
        put("neg", .ordinary("\u{00AC}"))
        put("hbar", .ordinary("\u{210F}"))
        put("ell", .ordinary("\u{2113}"))
        put("Re", .ordinary("\u{211C}"))
        put("Im", .ordinary("\u{2111}"))
        put("aleph", .ordinary("\u{2135}"))
        put("prime", .ordinary("\u{2032}"))
        put("ldots", .ordinary("\u{2026}"))
        put("cdots", .ordinary("\u{22EF}"))
        put("vdots", .ordinary("\u{22EE}"))
        put("ddots", .ordinary("\u{22F1}"))
        put("angle", .ordinary("\u{2220}"))
        put("triangle", .ordinary("\u{25B3}"))
        put("degree", .ordinary("\u{00B0}"))

        // Spacing (mu)
        put(",", .space(mu: 3))
        put(">", .space(mu: 4))
        put(";", .space(mu: 5))
        put("!", .space(mu: -3))
        put("quad", .space(mu: 18))
        put("qquad", .space(mu: 36))

        // Extended AMS / iosMath symbol parity
put("varkappa", .ordinary("\u{03F0}"))
        put("nwarrow", .relation("\u{2196}"))
        put("nearrow", .relation("\u{2197}"))
        put("searrow", .relation("\u{2198}"))
        put("swarrow", .relation("\u{2199}"))
        put("Updownarrow", .relation("\u{21D5}"))
        put("longmapsto", .relation("\u{27FC}"))
        put("hookrightarrow", .relation("\u{21AA}"))
        put("hookleftarrow", .relation("\u{21A9}"))
        put("leqslant", .relation("\u{2A7D}"))
        put("geqslant", .relation("\u{2A7E}"))
        put("asymp", .relation("\u{224D}"))
        put("doteq", .relation("\u{2250}"))
        put("prec", .relation("\u{227A}"))
        put("succ", .relation("\u{227B}"))
        put("preceq", .relation("\u{2AAF}"))
        put("succeq", .relation("\u{2AB0}"))
        put("sqsubset", .relation("\u{228F}"))
        put("sqsupset", .relation("\u{2290}"))
        put("sqsubseteq", .relation("\u{2291}"))
        put("sqsupseteq", .relation("\u{2292}"))
        put("models", .relation("\u{22A7}"))
        put("vdash", .relation("\u{22A2}"))
        put("dashv", .relation("\u{22A3}"))
        put("bowtie", .relation("\u{22C8}"))
        put("nless", .relation("\u{226E}"))
        put("ngtr", .relation("\u{226F}"))
        put("nleq", .relation("\u{2270}"))
        put("ngeq", .relation("\u{2271}"))
        put("nleqslant", .relation("\u{2A87}"))
        put("ngeqslant", .relation("\u{2A88}"))
        put("lneq", .relation("\u{2A87}"))
        put("gneq", .relation("\u{2A88}"))
        put("lneqq", .relation("\u{2268}"))
        put("gneqq", .relation("\u{2269}"))
        put("lnsim", .relation("\u{22E6}"))
        put("gnsim", .relation("\u{22E7}"))
        put("lnapprox", .relation("\u{2A89}"))
        put("gnapprox", .relation("\u{2A8A}"))
        put("nprec", .relation("\u{2280}"))
        put("nsucc", .relation("\u{2281}"))
        put("npreceq", .relation("\u{22E0}"))
        put("nsucceq", .relation("\u{22E1}"))
        put("precneqq", .relation("\u{2AB5}"))
        put("succneqq", .relation("\u{2AB6}"))
        put("precnsim", .relation("\u{22E8}"))
        put("succnsim", .relation("\u{22E9}"))
        put("precnapprox", .relation("\u{2AB9}"))
        put("succnapprox", .relation("\u{2ABA}"))
        put("nsim", .relation("\u{2241}"))
        put("ncong", .relation("\u{2247}"))
        put("nmid", .relation("\u{2224}"))
        put("nshortmid", .relation("\u{2224}"))
        put("nparallel", .relation("\u{2226}"))
        put("nshortparallel", .relation("\u{2226}"))
        put("nsubseteq", .relation("\u{2288}"))
        put("nsupseteq", .relation("\u{2289}"))
        put("subsetneq", .relation("\u{228A}"))
        put("supsetneq", .relation("\u{228B}"))
        put("subsetneqq", .relation("\u{2ACB}"))
        put("supsetneqq", .relation("\u{2ACC}"))
        put("varsubsetneq", .relation("\u{228A}"))
        put("varsupsetneq", .relation("\u{228B}"))
        put("varsubsetneqq", .relation("\u{2ACB}"))
        put("varsupsetneqq", .relation("\u{2ACC}"))
        put("notni", .relation("\u{220C}"))
        put("nni", .relation("\u{220C}"))
        put("ntriangleleft", .relation("\u{22EA}"))
        put("ntriangleright", .relation("\u{22EB}"))
        put("ntrianglelefteq", .relation("\u{22EC}"))
        put("ntrianglerighteq", .relation("\u{22ED}"))
        put("nvdash", .relation("\u{22AC}"))
        put("nvDash", .relation("\u{22AD}"))
        put("nVdash", .relation("\u{22AE}"))
        put("nVDash", .relation("\u{22AF}"))
        put("nsqsubseteq", .relation("\u{22E2}"))
        put("nsqsupseteq", .relation("\u{22E3}"))
        put("dagger", .binaryOperator("\u{2020}"))
        put("ddagger", .binaryOperator("\u{2021}"))
        put("wr", .binaryOperator("\u{2240}"))
        put("uplus", .binaryOperator("\u{228E}"))
        put("sqcap", .binaryOperator("\u{2293}"))
        put("sqcup", .binaryOperator("\u{2294}"))
        put("diamond", .binaryOperator("\u{22C4}"))
        put("amalg", .binaryOperator("\u{2A3F}"))
        put("ltimes", .binaryOperator("\u{22C9}"))
        put("rtimes", .binaryOperator("\u{22CA}"))
        put("circledast", .binaryOperator("\u{229B}"))
        put("circledcirc", .binaryOperator("\u{229A}"))
        put("circleddash", .binaryOperator("\u{229D}"))
        put("boxdot", .binaryOperator("\u{22A1}"))
        put("boxminus", .binaryOperator("\u{229F}"))
        put("boxplus", .binaryOperator("\u{229E}"))
        put("boxtimes", .binaryOperator("\u{22A0}"))
        put("divideontimes", .binaryOperator("\u{22C7}"))
        put("dotplus", .binaryOperator("\u{2214}"))
        put("lhd", .binaryOperator("\u{22B2}"))
        put("rhd", .binaryOperator("\u{22B3}"))
        put("unlhd", .binaryOperator("\u{22B4}"))
        put("unrhd", .binaryOperator("\u{22B5}"))
        put("intercal", .binaryOperator("\u{22BA}"))
        put("barwedge", .binaryOperator("\u{22BC}"))
        put("veebar", .binaryOperator("\u{22BB}"))
        put("curlywedge", .binaryOperator("\u{22CF}"))
        put("curlyvee", .binaryOperator("\u{22CE}"))
        put("doublebarwedge", .binaryOperator("\u{2A5E}"))
        put("centerdot", .binaryOperator("\u{22C5}"))
        put("cdotp", .punctuation("\u{00B7}"))
        put("angstrom", .ordinary("\u{00C5}"))
        put("aa", .ordinary("\u{00E5}"))
        put("ae", .ordinary("\u{00E6}"))
        put("o", .ordinary("\u{00F8}"))
        put("oe", .ordinary("\u{0153}"))
        put("ss", .ordinary("\u{00DF}"))
        put("cc", .ordinary("\u{00E7}"))
        put("CC", .ordinary("\u{00C7}"))
        put("O", .ordinary("\u{00D8}"))
        put("AE", .ordinary("\u{00C6}"))
        put("OE", .ordinary("\u{0152}"))
        put("lbar", .ordinary("\u{019B}"))
        put("wp", .ordinary("\u{2118}"))
        put("mho", .ordinary("\u{2127}"))
        put("beth", .ordinary("\u{2136}"))
        put("gimel", .ordinary("\u{2137}"))
        put("daleth", .ordinary("\u{2138}"))
        put("nexists", .ordinary("\u{2204}"))
        put("varnothing", .ordinary("\u{2205}"))
        put("measuredangle", .ordinary("\u{2221}"))
        put("top", .ordinary("\u{22A4}"))
        put("bot", .ordinary("\u{22A5}"))
        put("Box", .ordinary("\u{25A1}"))
        put("imath", .ordinary("\u{1D6A4}"))
        put("jmath", .ordinary("\u{1D6A5}"))
        put("upquote", .ordinary("'"))
        put("arccot", .largeOperator("arccot", limits: false))
        put("arcsec", .largeOperator("arcsec", limits: false))
        put("arccsc", .largeOperator("arccsc", limits: false))
        put("sech", .largeOperator("sech", limits: false))
        put("csch", .largeOperator("csch", limits: false))
        put("arcsinh", .largeOperator("arcsinh", limits: false))
        put("arccosh", .largeOperator("arccosh", limits: false))
        put("arctanh", .largeOperator("arctanh", limits: false))
        put("arccoth", .largeOperator("arccoth", limits: false))
        put("arcsech", .largeOperator("arcsech", limits: false))
        put("arccsch", .largeOperator("arccsch", limits: false))
        put("iiiint", .largeOperator("\u{2A0C}", limits: false))
        put("bigodot", .largeOperator("\u{2A00}", limits: true))
        put("bigoplus", .largeOperator("\u{2A01}", limits: true))
        put("bigotimes", .largeOperator("\u{2A02}", limits: true))
        put("biguplus", .largeOperator("\u{2A04}", limits: true))
        put("bigsqcup", .largeOperator("\u{2A06}", limits: true))

        put(":", .space(mu: 4))

        // Style
        put("displaystyle", .style(.display))
        put("textstyle", .style(.text))
        put("scriptstyle", .style(.script))
        put("scriptscriptstyle", .style(.scriptScript))

        return table
    }()

    public static func resolveAlias(_ command: String) -> String {
        aliases[command] ?? command
    }

    public static func atom(forCommand command: String) -> MathAtom? {
        let name = resolveAlias(command)
        return symbols[name]
    }

    public static func atom(forCharacter ch: Character) -> MathAtom? {
        if ch == "^" || ch == "_" || ch == "{" || ch == "}" || ch == "\\" {
            return nil
        }
        if ch == " " || ch == "\n" || ch == "\t" || ch == "\r" {
            return nil
        }
        if ch.isNumber {
            return .number(String(ch))
        }
        if ("a"..."z").contains(ch) || ("A"..."Z").contains(ch) {
            return .variable(String(ch))
        }
        switch ch {
        case "+", "-", "*", "/", "=":
            if ch == "=" { return .relation("=") }
            if ch == "+" || ch == "-" { return .binaryOperator(String(ch)) }
            return .binaryOperator(String(ch))
        case "<", ">":
            return .relation(String(ch))
        case "(", "[":
            return .open(String(ch))
        case ")", "]":
            return .close(String(ch))
        case ",", ";", ".", ":", "!", "?":
            return .punctuation(String(ch))
        case "|":
            return .ordinary("|")
        default:
            return .ordinary(String(ch))
        }
    }

    public static func boundaryNucleus(forDelimiter name: String) -> String? {
        delimiters[name]
    }
}
