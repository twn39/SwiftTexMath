import Testing
@testable import SwiftTexMathCore

@Suite("LatexSerializer Coverage")
struct LatexSerializerCoverageTests {
    @Test("Serialize fractions and binoms with styles")
    func testFractionAndBinomSerialization() throws {
        let dfrac = try MathParser.parse(#"\dfrac{a}{b}"#)
        #expect(dfrac.latexString == #"\dfrac{a}{b}"#)

        let tfrac = try MathParser.parse(#"\tfrac{a}{b}"#)
        #expect(tfrac.latexString == #"\tfrac{a}{b}"#)

        let binom = try MathParser.parse(#"\binom{a}{b}"#)
        #expect(binom.latexString == #"\binom{a}{b}"#)

        let dbinom = try MathParser.parse(#"\dbinom{a}{b}"#)
        #expect(dbinom.latexString == #"\dbinom{a}{b}"#)

        let tbinom = try MathParser.parse(#"\tbinom{a}{b}"#)
        #expect(tbinom.latexString == #"\tbinom{a}{b}"#)
    }

    @Test("Serialize radicals with and without degree")
    func testRadicalSerialization() throws {
        let sqrt = try MathParser.parse(#"\sqrt{x}"#)
        #expect(sqrt.latexString == #"\sqrt{x}"#)

        let root = try MathParser.parse(#"\sqrt[3]{x}"#)
        #expect(root.latexString == #"\sqrt[3]{x}"#)
    }

    @Test("Serialize inner delimiters and heights")
    func testInnerSerialization() throws {
        let leftRight = try MathParser.parse(#"\left( x \right)"#)
        #expect(leftRight.latexString == #"\left(x\right)"#)

        let leftDot = try MathParser.parse(#"\left. x \right)"#)
        #expect(leftDot.latexString == #"\left.x\right)"#)
    }

    @Test("Serialize spaces and mu values")
    func testSpaceSerialization() throws {
        let thin = try MathParser.parse(#"a\,b"#)
        #expect(thin.latexString == #"a\,b"#)

        let med = try MathParser.parse(#"a\:b"#)
        #expect(med.latexString == #"a\:b"#)

        let thick = try MathParser.parse(#"a\;b"#)
        #expect(thick.latexString == #"a\;b"#)

        let neg = try MathParser.parse(#"a\!b"#)
        #expect(neg.latexString == #"a\!b"#)

        let quad = try MathParser.parse(#"a\quad b"#)
        #expect(quad.latexString == #"a\quad b"#)

        let qquad = try MathParser.parse(#"a\qquad b"#)
        #expect(qquad.latexString == #"a\qquad b"#)

        // Custom mu space
        let customSpace = MathList(atoms: [MathAtom(kind: .space, nucleus: "", payload: .space(mu: 7.5))])
        #expect(customSpace.latexString == #"\mkern{7.5mu}"#)

        let integerSpace = MathList(atoms: [MathAtom(kind: .space, nucleus: "", payload: .space(mu: 10.0))])
        #expect(integerSpace.latexString == #"\mkern{10mu}"#)
    }

    @Test("Serialize styles and math variants")
    func testStyleAndVariantSerialization() throws {
        let styles = try MathParser.parse(#"\displaystyle a \textstyle b \scriptstyle c \scriptscriptstyle d"#)
        #expect(styles.latexString.contains(#"\displaystyle"#))
        #expect(styles.latexString.contains(#"\textstyle"#))
        #expect(styles.latexString.contains(#"\scriptstyle"#))

        let rm = try MathParser.parse(#"\mathrm{X}"#)
        #expect(rm.latexString == #"\mathrm{X}"#)

        let bf = try MathParser.parse(#"\mathbf{X}"#)
        #expect(bf.latexString == #"\mathbf{X}"#)

        let it = try MathParser.parse(#"\mathit{X}"#)
        #expect(it.latexString == #"\mathit{X}"#)

        let bb = try MathParser.parse(#"\mathbb{R}"#)
        #expect(bb.latexString == #"\mathbb{R}"#)

        let cal = try MathParser.parse(#"\mathcal{L}"#)
        #expect(cal.latexString == #"\mathcal{L}"#)
    }

    @Test("Serialize box strikes, phantoms, and aligns")
    func testBoxSerialization() throws {
        let cancel = try MathParser.parse(#"\cancel{x}"#)
        #expect(cancel.latexString == #"\cancel{x}"#)

        let bcancel = try MathParser.parse(#"\bcancel{x}"#)
        #expect(bcancel.latexString == #"\bcancel{x}"#)

        let xcancel = try MathParser.parse(#"\xcancel{x}"#)
        #expect(xcancel.latexString == #"\xcancel{x}"#)

        let sout = try MathParser.parse(#"\sout{x}"#)
        #expect(sout.latexString == #"\sout{x}"#)

        let boxed = try MathParser.parse(#"\boxed{x}"#)
        #expect(boxed.latexString == #"\boxed{x}"#)

        let phantom = try MathParser.parse(#"\phantom{x}"#)
        #expect(phantom.latexString == #"\phantom{x}"#)

        let hphantom = try MathParser.parse(#"\hphantom{x}"#)
        #expect(hphantom.latexString == #"\hphantom{x}"#)

        let vphantom = try MathParser.parse(#"\vphantom{x}"#)
        #expect(vphantom.latexString == #"\vphantom{x}"#)

        let smash = try MathParser.parse(#"\smash{x}"#)
        #expect(smash.latexString == #"\smash{x}"#)

        let llap = try MathParser.parse(#"\llap{x}"#)
        #expect(llap.latexString == #"\llap{x}"#)

        let rlap = try MathParser.parse(#"\rlap{x}"#)
        #expect(rlap.latexString == #"\rlap{x}"#)

        let clap = try MathParser.parse(#"\clap{x}"#)
        #expect(clap.latexString == #"\clap{x}"#)
    }

    @Test("Serialize stacks and accents")
    func testStackAndAccentSerialization() throws {
        let overset = try MathParser.parse(#"\overset{a}{b}"#)
        #expect(overset.latexString == #"\overset{a}{b}"#)

        let underset = try MathParser.parse(#"\underset{a}{b}"#)
        #expect(underset.latexString == #"\underset{a}{b}"#)

        let hat = try MathParser.parse(#"\hat{x}"#)
        #expect(hat.latexString == #"\hat{x}"#)

        let widehat = try MathParser.parse(#"\widehat{xyz}"#)
        #expect(widehat.latexString == #"\widehat{xyz}"#)

        let overline = try MathParser.parse(#"\overline{x}"#)
        #expect(overline.latexString == #"\overline{x}"#)

        let underline = try MathParser.parse(#"\underline{x}"#)
        #expect(underline.latexString == #"\underline{x}"#)
    }

    @Test("Serialize tables and matrices")
    func testTableSerialization() throws {
        let pmatrix = try MathParser.parse(#"\begin{pmatrix} a & b \\ c & d \end{pmatrix}"#)
        #expect(pmatrix.latexString == #"\begin{pmatrix}a & b \\c & d\end{pmatrix}"#)

        let array = try MathParser.parse(#"\begin{array}{cc} a & b \end{array}"#)
        #expect(array.latexString == #"\begin{array}{cc}a & b\end{array}"#)
    }

    @Test("Serialize colors, mathchoices, tags, labels, refs")
    func testColorTagLabelRefSerialization() throws {
        let color = try MathParser.parse(#"\color{red}{x}"#)
        #expect(color.latexString == #"\color{red}{x}"#)

        let colorbox = try MathParser.parse(#"\colorbox{blue}{x}"#)
        #expect(colorbox.latexString == #"\colorbox{blue}{x}"#)

        let choice = try MathParser.parse(#"\mathchoice{A}{B}{C}{D}"#)
        #expect(choice.latexString.contains(#"\mathchoice"#))

        let tag = try MathParser.parse(#"\tag{1}"#)
        #expect(tag.latexString == #"\tag{1}"#)

        let tagStar = try MathParser.parse(#"\tag*{1}"#)
        #expect(tagStar.latexString == #"\tag*{1}"#)

        let notag = try MathParser.parse(#"\notag"#)
        #expect(notag.latexString == #"\notag"#)

        let label = try MathParser.parse(#"\label{eq:1}"#)
        #expect(label.latexString == #"\label{eq:1}"#)

        let ref = try MathParser.parse(#"\ref{eq:1}"#)
        #expect(ref.latexString == #"\ref{eq:1}"#)

        let eqref = try MathParser.parse(#"\eqref{eq:1}"#)
        #expect(eqref.latexString == #"\eqref{eq:1}"#)
    }
}
