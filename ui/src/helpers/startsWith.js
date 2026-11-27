'use strict'

module.exports = (text, prefix) => typeof text === 'string' && text.startsWith(prefix)
