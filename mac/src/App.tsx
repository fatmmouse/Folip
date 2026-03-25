function App() {
  return (
    <div
      style={{
        width: "100%",
        height: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "var(--color-dominant)",
        borderRadius: "12px",
        border: "1px solid var(--color-secondary)",
        boxShadow: "0 8px 32px rgba(20, 20, 19, 0.15)",
      }}
    >
      <span
        style={{
          fontSize: "15px",
          fontWeight: 600,
          color: "var(--color-text-primary)",
        }}
      >
        Folip
      </span>
    </div>
  );
}

export default App;
