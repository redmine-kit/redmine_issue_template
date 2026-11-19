// Vite's ?raw imports (the tests read the plugin's locale files as text).
declare module '*?raw' {
  const text: string;
  export default text;
}
