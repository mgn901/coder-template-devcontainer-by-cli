(() => {
  try {
    const config = JSON.stringify(require('fs').readFileSync('/dev/stdin', 'utf8'));
    if ('dockerComposeFile' in config) {
      console.log('true');
    } else {
      console.log('false');
    }
  } catch (error) {
    console.error("ERROR: devcontainer.json is invalid or not found");
    console.error(error.message);
    process.exit(1);
  }
})();
