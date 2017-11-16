function genfdgraph(svg, graph){
  var simulation,
      color = d3.scaleOrdinal(d3.schemeCategory20),
      width = 500, // svg.viewBox.baseVal.width, // svg._groups[0][0].scrollWidth,
      height = 500; // svg.viewBox.baseVal.height; // svg._groups[0][0].scrollHeight;

  var render_table_template = (function(){
    var source = $("#graph-table-template").html();
    var template = Handlebars.compile(source);

    return function(context){
      var html = template(context);
      $("#graph-table-wrapper").html(html);
    };
  })();

  render_table_template({rows: []});


  var updateSelectedNode = function(selected_node, all_nodes, d){
    // deselect previous selected nodes
    all_nodes.classed("selected", false);

    // select new node
    selected_node.classed("selected", true);

    // GOaccessions, GOdescriptions, GOnames are empty: "" or: | delimited strings
    d_zipped = [];
    if(d.GOaccessions != "" && d.GOdescriptions != "" && d.GOnames != ""){
      // convert separate arrays into 1 array of objects
      d_zipped = _.zipWith(d.GOaccessions.split("|"), d.GOdescriptions.split("|"), d.GOnames.split("|"), function(accession, description, name){
        return {
          accession: accession,
          description: description,
          name: name
        };
      });
    }

    // render table rows
    render_table_template({rows: d_zipped, id: d.id, gene: d.gene_symbol });
  };

  var dragstarted = function(d) {
    if (!d3.event.active) simulation.alphaTarget(0.3).restart();
    d.fx = d.x;
    d.fy = d.y;

    updateSelectedNode(d3.select(this), node, d);
  };

  var dragged = function(d) {
    d.fx = d3.event.x;
    d.fy = d3.event.y;
  };
  var dragended = function(d) {
    if (!d3.event.active) simulation.alphaTarget(0);
    d.fx = null;
    d.fy = null;
  };

  //update display
  svg.selectAll().remove();
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
      .style("fill-opacity", function(d){
        return d.GOnames == "" ? 0.5 : 1.0;
      })
      .attr("fill", d3.rgb('#ff8282'))//function(d) { return color(d.group); })
      .on("click", function(d){
        updateSelectedNode(d3.select(this), node, d);
      })
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
