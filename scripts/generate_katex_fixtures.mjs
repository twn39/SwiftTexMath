import fs from 'node:fs';
import path from 'node:path';
import katex from 'katex';

const CATEGORY_FORMULAS = [
  // 1. Functions & Multi-character Operators
  { id: "op_sin", latex: String.raw`\sin(x)` },
  { id: "op_cos", latex: String.raw`\cos(x)` },
  { id: "op_tan", latex: String.raw`\tan(\theta)` },
  { id: "op_trig_identity", latex: String.raw`\sin^2(x) + \cos^2(x) = 1` },
  { id: "op_log_ln", latex: String.raw`\ln(x) + \log_{10}(y)` },
  { id: "op_lim", latex: String.raw`\lim_{n \to \infty} \left(1 + \frac{1}{n}\right)^n = e` },
  { id: "op_min_max", latex: String.raw`\max(a, b) + \min(c, d) + \sup E + \inf S` },
  { id: "op_custom_operatorname", latex: String.raw`\operatorname{Hom}(A, B) \otimes \operatorname{Ker}(f)` },
  { id: "op_hyperbolic", latex: String.raw`\sinh(x) + \cosh(y) = \tanh(z)` },
  { id: "op_mod_tag", latex: String.raw`a \equiv b \pmod{m}` },

  // 2. Fractions, Binomials & Stacks
  { id: "frac_simple", latex: String.raw`\frac{a}{b}` },
  { id: "frac_complex", latex: String.raw`\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}` },
  { id: "frac_cfrac", latex: String.raw`a_0 + \cfrac{1}{a_1 + \cfrac{1}{a_2}}` },
  { id: "binom", latex: String.raw`\binom{n}{k} = \frac{n!}{k!(n-k)!}` },
  { id: "overset_underset", latex: String.raw`\overset{\text{def}}{=} A \underset{x \to 0}{\longrightarrow} B` },
  { id: "overbrace_underbrace", latex: String.raw`\underbrace{a + b + \dots + z}_{26 \text{ terms}} = S` },

  // 3. Radicals & Accents
  { id: "sqrt_simple", latex: String.raw`\sqrt{x+1}` },
  { id: "sqrt_nth", latex: String.raw`\sqrt[3]{x^2 + y^2}` },
  { id: "accents_single", latex: String.raw`\hat{a} + \bar{b} + \vec{c} + \dot{d} + \ddot{e} + \tilde{f}` },
  { id: "accents_wide", latex: String.raw`\widehat{AB} + \widetilde{XYZ} + \overrightarrow{PQ} + \overleftarrow{MN}` },
  { id: "lines_over_under", latex: String.raw`\overline{x+y} + \underline{z+w}` },

  // 4. Delimiters & Large Fences
  { id: "delim_paren", latex: String.raw`\left( \frac{a+1}{b+2} \right)` },
  { id: "delim_brackets", latex: String.raw`\left[ x + \left\{ y + z \right\} \right]` },
  { id: "delim_norm_abs", latex: String.raw`\left| x \right| + \left\| v \right\| + \langle u, v \rangle` },
  { id: "delim_big_variants", latex: String.raw`\big( \Big[ \bigg\{ \Bigg| x \Bigg| \bigg\} \Big] \big)` },

  // 5. Large Operators & Calculus
  { id: "largeop_sum", latex: String.raw`\sum_{i=1}^{n} i^2 = \frac{n(n+1)(2n+1)}{6}` },
  { id: "largeop_prod", latex: String.raw`\prod_{k=1}^{\infty} \left(1 - \frac{1}{k^2}\right)` },
  { id: "largeop_int", latex: String.raw`\int_{0}^{1} x^2 dx = \frac{1}{3}` },
  { id: "largeop_multi_int", latex: String.raw`\iint_D f(x,y) \, dx \, dy + \iiint_V g(x,y,z) \, dV` },
  { id: "largeop_oint", latex: String.raw`\oint_C F \cdot dr = \oiint_S (\nabla \times F) \cdot dS` },

  // 6. Calculus, Differential Equations & Physics
  { id: "pde_laplacian", latex: String.raw`\frac{\partial^2 u}{\partial x^2} + \frac{\partial^2 u}{\partial y^2} = 0` },
  { id: "fourier_transform", latex: String.raw`\hat{f}(\xi) = \int_{-\infty}^{\infty} f(x) e^{-2\pi i x \xi} \, dx` },
  { id: "schrodinger_eq", latex: String.raw`i\hbar \frac{\partial}{\partial t} |\psi(t)\rangle = \hat{H} |\psi(t)\rangle` },
  { id: "bessel_func", latex: String.raw`J_\alpha(x) = \sum_{m=0}^\infty \frac{(-1)^m}{m! \Gamma(m+\alpha+1)} \left(\frac{x}{2}\right)^{2m+\alpha}` },

  // 7. Matrices & Environments
  { id: "matrix_pmatrix", latex: String.raw`\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}` },
  { id: "matrix_bmatrix", latex: String.raw`\begin{bmatrix} a & b \\ c & d \end{bmatrix}` },
  { id: "matrix_vmatrix", latex: String.raw`\begin{vmatrix} x & y \\ z & w \end{vmatrix}` },
  { id: "env_cases", latex: String.raw`f(x) = \begin{cases} x^2 & x \ge 0 \\ -x & x < 0 \end{cases}` },
  { id: "env_aligned", latex: String.raw`\begin{aligned} a &= b + c \\ d &= e + f \end{aligned}` },
  { id: "env_array", latex: String.raw`\begin{array}{c|c} 1 & 2 \\ \hline 3 & 4 \end{array}` },
  { id: "env_substack", latex: String.raw`\sum_{\substack{0 \le i \le n \\ 0 \le j \le m}} P(i,j)` },

  // 8. Math Styles, Fonts & Logic
  { id: "fonts_math", latex: String.raw`\mathbf{v} + \mathrm{d}x + \mathit{f}(x) + \mathsf{A} + \mathtt{code} + \mathcal{L} + \mathbb{R} + \mathfrak{g}` },
  { id: "logic_quantifiers", latex: String.raw`\forall x \in \mathbb{R}, \exists y > 0 \text{ s.t. } y = x^2 + 1` },
  { id: "symbols_greek", latex: String.raw`\alpha + \beta + \gamma = \pi + \theta + \Omega + \Delta` },
  { id: "symbols_relations", latex: String.raw`x \le y \ge z \neq w \approx a \equiv b \in \mathbb{R} \subset S` },
  { id: "symbols_arrows", latex: String.raw`A \to B \Rightarrow C \iff D \nearrow E` }
];

function parseMathMLDetails(mathmlString) {
  const tokens = [];
  const nodeTypes = [];

  // Match all leaf text elements: <mi>, <mo>, <mn>, <mtext>
  const leafRegex = /<(mi|mo|mn|mtext)\b[^>]*>(.*?)<\/\1>/gs;
  let match;
  while ((match = leafRegex.exec(mathmlString)) !== null) {
    const tagName = match[1];
    const rawText = match[2].replace(/<[^>]+>/g, '').trim();
    if (rawText && rawText !== '&#x200b;' && rawText !== '\u200b') {
      const text = rawText
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&amp;/g, '&')
        .replace(/&quot;/g, '"');
      tokens.push(text);
      nodeTypes.push(tagName);
    }
  }

  // Match structural tags
  const structRegex = /<(mfrac|msqrt|mroot|mtable|msub|msup|msubsup|munder|mover|munderover)\b/g;
  while ((match = structRegex.exec(mathmlString)) !== null) {
    nodeTypes.push(match[1]);
  }

  return { tokens, nodeTypes };
}

function extractMetricsFromHTML(htmlString) {
  let maxAscent = 0;
  let maxDescent = 0;

  const strutRegex = /<span class="strut"[^>]*style="([^"]*)"/g;
  let match;
  while ((match = strutRegex.exec(htmlString)) !== null) {
    const style = match[1];
    const heightMatch = /height:\s*([\d\.]+)em/.exec(style);
    if (heightMatch) {
      maxAscent = Math.max(maxAscent, parseFloat(heightMatch[1]));
    }
    const alignMatch = /vertical-align:\s*-([\d\.]+)em/.exec(style);
    if (alignMatch) {
      maxDescent = Math.max(maxDescent, parseFloat(alignMatch[1]));
    }
  }

  return {
    ascentEm: maxAscent,
    descentEm: maxDescent,
    totalHeightEm: maxAscent + maxDescent
  };
}

function loadCorpusCatalog() {
  const corpusPath = path.resolve('Tests/SwiftTexMathCoreTests/Tex2MathCorpus/catalog.json');
  if (!fs.existsSync(corpusPath)) return [];
  try {
    const content = fs.readFileSync(corpusPath, 'utf-8');
    const catalog = JSON.parse(content);
    return catalog
      .filter(item => !item.expectError && item.latex)
      .map(item => ({
        id: `corpus/${item.id.replace(/[^a-zA-Z0-9_\-\/]/g, '_')}`,
        latex: item.latex
      }));
  } catch (err) {
    console.warn("Could not load Tex2MathCorpus catalog:", err.message);
    return [];
  }
}

function generateFixtures() {
  const corpusItems = loadCorpusCatalog();
  const allTargets = [...CATEGORY_FORMULAS, ...corpusItems];

  const fixtures = [];
  let successCount = 0;
  let errorCount = 0;

  for (const item of allTargets) {
    try {
      const mathmlDisplay = katex.renderToString(item.latex, { output: 'mathml', displayMode: true });
      const htmlDisplay = katex.renderToString(item.latex, { output: 'html', displayMode: true });
      const htmlText = katex.renderToString(item.latex, { output: 'html', displayMode: false });
      
      const { tokens, nodeTypes } = parseMathMLDetails(mathmlDisplay);
      const displayMetrics = extractMetricsFromHTML(htmlDisplay);
      const textMetrics = extractMetricsFromHTML(htmlText);

      fixtures.push({
        id: item.id,
        latex: item.latex,
        tokens: tokens,
        nodeTypes: nodeTypes,
        metrics: displayMetrics,
        displayMetrics: displayMetrics,
        textMetrics: textMetrics,
        features: {
          hasFraction: item.latex.includes(String.raw`\frac`) || item.latex.includes(String.raw`\cfrac`),
          hasRadical: item.latex.includes(String.raw`\sqrt`),
          hasMatrix: item.latex.includes(String.raw`\begin{`) || item.latex.includes(String.raw`matrix`),
          hasLargeOp: item.latex.includes(String.raw`\sum`) || item.latex.includes(String.raw`\int`) || item.latex.includes(String.raw`\prod`),
          hasAccent: item.latex.includes(String.raw`\hat`) || item.latex.includes(String.raw`\vec`) || item.latex.includes(String.raw`\bar`)
        }
      });
      successCount++;
    } catch (err) {
      errorCount++;
    }
  }

  const outputDir = path.resolve('Tests/SwiftTexMathCoreTests/Fixtures');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const outputPath = path.join(outputDir, 'katex_geometry_goldens.json');
  fs.writeFileSync(outputPath, JSON.stringify(fixtures, null, 2), 'utf-8');
  console.log(`Successfully generated ${successCount} KaTeX rich golden fixtures (skipped ${errorCount}) at: ${outputPath}`);
}

generateFixtures();
