module.exports = function(eleventyConfig) {
  eleventyConfig.addPassthroughCopy("css");
  
  return {
    dir: {
      input: ".",
      includes: "_includes",
      output: "_site"
    }
  };
};