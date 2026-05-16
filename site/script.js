const demo = document.querySelector("[data-scan-demo]");

if (demo) {
  const questions = Array.from(demo.querySelectorAll("[data-question]"));
  const resultPanel = demo.querySelector("[data-result-panel]");
  const questionPanel = demo.querySelector("[data-question-panel]");
  const progressLabel = demo.querySelector("[data-progress-label]");
  const progressBar = demo.querySelector("[data-progress-bar]");
  const resultImage = demo.querySelector("[data-result-image]");
  const resultScore = demo.querySelector("[data-result-score]");
  const resultTitle = demo.querySelector("[data-result-title]");
  const resultCopy = demo.querySelector("[data-result-copy]");
  const restartButton = demo.querySelector("[data-restart]");
  const answers = [];

  const resultTypes = [
    {
      title: "Read Receipt Royalty",
      image: "/assets/avatar-read-receipt.webp",
      copy: "You act unavailable but reply instantly.",
      score: 84,
    },
    {
      title: "Main Character Energy",
      image: "/assets/avatar-main-character.webp",
      copy: "You call it casual, but the room remembers the entrance.",
      score: 88,
    },
    {
      title: "Soft Chaos",
      image: "/assets/avatar-soft-chaos.webp",
      copy: "Sweet intentions. Loud inner monologue.",
      score: 79,
    },
    {
      title: "Unbothered",
      image: "/assets/avatar-unbothered.webp",
      copy: "Calm face. Notes app documentary.",
      score: 76,
    },
  ];

  let currentIndex = 0;

  const showQuestion = (index) => {
    currentIndex = index;
    questions.forEach((question, questionIndex) => {
      question.classList.toggle("is-active", questionIndex === index);
    });
    progressLabel.textContent = `Question ${index + 1} of ${questions.length}`;
    progressBar.style.width = `${((index + 1) / questions.length) * 100}%`;
  };

  const chooseResult = () => {
    const [texting = 1, chill = 1, spotlight = 1] = answers;

    if (texting >= 2 && chill >= 1) return resultTypes[0];
    if (spotlight >= 2) return resultTypes[1];
    if (chill >= 2) return resultTypes[3];
    return resultTypes[2];
  };

  const revealResult = () => {
    const result = chooseResult();
    resultImage.src = result.image;
    resultTitle.textContent = result.title;
    resultCopy.textContent = result.copy;
    resultScore.textContent = result.score;
    questionPanel.style.display = "none";
    resultPanel.style.display = "grid";
  };

  demo.addEventListener("click", (event) => {
    const button = event.target.closest("[data-answer]");
    if (!button) return;

    answers[currentIndex] = Number(button.dataset.answer);

    if (currentIndex >= questions.length - 1) {
      revealResult();
    } else {
      showQuestion(currentIndex + 1);
    }
  });

  restartButton.addEventListener("click", () => {
    answers.length = 0;
    resultPanel.style.display = "";
    questionPanel.style.display = "";
    showQuestion(0);
  });

  showQuestion(0);
}

const syncStickyCta = () => {
  const hero = document.querySelector(".hero");
  const heroBottom = hero ? hero.getBoundingClientRect().bottom : 0;
  document.body.classList.toggle("show-sticky", heroBottom < 120);
};

syncStickyCta();
window.addEventListener("scroll", syncStickyCta, {passive: true});
