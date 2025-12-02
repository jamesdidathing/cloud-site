module.exports = function(eleventyConfig) {
  eleventyConfig.addPassthroughCopy("src/css");
  eleventyConfig.addPassthroughCopy("src/images");

   // Date filters for blog
  eleventyConfig.addFilter("dateIso", (date) => {
    return new Date(date).toISOString();
  });

  eleventyConfig.addFilter("dateReadable", (date) => {
    return new Date(date).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  });
  
  return {
    dir: {
      input: "src",
      includes: "_includes",
      output: "_site"
    }
  };
};