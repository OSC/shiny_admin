// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require bootstrap-sprockets
//= require dataTables/jquery.dataTables
//= require dataTables/bootstrap/3/jquery.dataTables.bootstrap
//= require_tree .

function genfdgraph(svg, graph){
  var simulation,
      color = d3.scaleOrdinal(d3.schemeCategory20),
      width = svg._groups[0][0].scrollWidth,
      height = svg._groups[0][0].scrollHeight;

  function dragstarted(d) {
    if (!d3.event.active) simulation.alphaTarget(0.3).restart();
    d.fx = d.x;
    d.fy = d.y;
  }
  function dragged(d) {
    d.fx = d3.event.x;
    d.fy = d3.event.y;
  }
  function dragended(d) {
    if (!d3.event.active) simulation.alphaTarget(0);
    d.fx = null;
    d.fy = null;
  }

  //update display
  d3.selectAll("svg > *").remove();
  simulation = d3.forceSimulation()
    .force("link", d3.forceLink())//.id(function(d) { return d.id; }))
    .force("charge", d3.forceManyBody().strength(function(d){return -20;}))
    .force("center", d3.forceCenter(width / 2, height / 2))
    .force("collide", d3.forceCollide().radius(function(d) { return 10; }).iterations(5));
  var link = svg.append("g")
      .attr("class", "links")
      .selectAll("line")
      .data(graph.links)
      .enter()
      .append("line")
      .attr("stroke-width", function(d) { return Math.sqrt(d.weight/100); });

  var node = svg.append("g")
      .attr("class", "nodes")
      .selectAll("circle")
      .data(graph.nodes)
      .enter()
      .append("circle")
      .attr("r", 10)
      .style("fill-opacity", .5)
      .attr("fill", d3.rgb('#ff8282'))//function(d) { return color(d.group); })
      .call(d3.drag()
        .on("start", dragstarted)
        .on("drag", dragged)
        .on("end", dragended));

  var label = svg.append("g")
      .attr("class","labels")
      .selectAll("text")
      .data(graph.nodes)
      .enter()
      .append("text")
      .text(function (d) { return d.id; })
      .style("text-anchor", "middle")
      .style("fill", "#555")
      .style("font-family", "Arial")
      .style("font-size", 10);

  function tickActions() {
    link
      .attr("x1", function(d) { return d.source.x; })
      .attr("y1", function(d) { return d.source.y; })
      .attr("x2", function(d) { return d.target.x; })
      .attr("y2", function(d) { return d.target.y; });
    node
      .attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; });
    label
      .attr("x", function(d){return d.x;})
      .attr("y", function(d){return d.y+5;})
  }
  simulation
    .nodes(graph.nodes)
    .on("tick", tickActions)
    .force("link").links(graph.links);
}
