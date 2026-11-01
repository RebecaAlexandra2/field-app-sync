const { getDefaultConfig } = require('expo/metro-config');
const { ServerResponse } = require('node:http');

const config = getDefaultConfig(__dirname);

// Migrările Drizzle și SQLite WebAssembly.
config.resolver.sourceExts.push('sql');
config.resolver.assetExts.push('wasm');

// SQLite web are nevoie de SharedArrayBuffer.
const writeHead = ServerResponse.prototype.writeHead;

ServerResponse.prototype.writeHead = function (...args) {
  this.setHeader('Cross-Origin-Embedder-Policy', 'credentialless');
  this.setHeader('Cross-Origin-Opener-Policy', 'same-origin');

  return writeHead.apply(this, args);
};

module.exports = config;