/*
   
Copyright 2010, Moritz Stefaner

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
   
 */

package eu.stefaner.elasticlists.data {	
	import eu.stefaner.elasticlists.App;

	import org.osflash.thunderbolt.Logger;

	import flash.events.EventDispatcher;
	import flash.utils.Dictionary;

	/**
	 *  Model
	 *	
	 *	manages ContentItem and Facet collections, filter states etc
	 *	
	 * 	@langversion ActionScript 3
	 *	@playerversion Flash 9.0.0
	 *
	 *	@author moritz@stefaner.eu
	 */
	public class Model extends EventDispatcher {

		public var app : App;
		public var facets : Array = [];
		public var facetValuesForContentItem : Dictionary = new Dictionary(true);
		public var activeFilters : Dictionary = new Dictionary(true);
		public var allContentItems : Array = [];
		public var filteredContentItems : Array = [];
		protected var allContentItemsForFacetValue : Dictionary = new Dictionary(true);
		protected var contentItemsById : Dictionary = new Dictionary(true);
		public static var ANDselectionWithinFacets : Boolean = false;

		public function Model(a : App) {
			app = a;
			init();
		};

		public function init() : void {
			facets = [];
			activeFilters = new Dictionary(true);
			facetValuesForContentItem = new Dictionary(true);
			allContentItems = [];
			filteredContentItems = [];
			allContentItemsForFacetValue = new Dictionary(true);
			contentItemsById = new Dictionary(true);
		}

		public function hasActiveFilters() : Boolean {
			return !(filteredContentItems.length == allContentItems.length);
		}

		// adds a facet
		public function registerFacet(f : Facet) : Facet {
			if(facet(f.name)) {
				throw new Error("Cannot add facet, because it is already present: " + f.name);
				return;
			}
			f.model = this;
			facets.push(f);
			// prepare lookup map per facet value
			for each (var facetValue:FacetValue in f.facetValues) {
				allContentItemsForFacetValue[facetValue] = [];
			}

			return f;
		}

		// returns a facet by name
		public function facet(name : String) : Facet {
			for each(var facet:Facet in facets) {
				if (facet.name == name) {
					return facet;
				}
			}
			return null;				
		}

		public function updateGlobalStats() : void {
			for each (var facet:Facet in facets) {
				facet.calcGlobalStats();
			}
		}

		public function updateLocalStats() : void {
			for each (var facet:Facet in facets) {
				facet.calcLocalStats();
			}
		}

		//---------------------------------------
		// CONTENTITEMS
		//---------------------------------------
		public function createContentItem(id : String) : ContentItem {
			return getContentItemById(id) || addContentItem(app.createContentItem(id));
		};

		public function getContentItemById(id : String) : ContentItem {
			return contentItemsById[id];
		}

		// REVISIT: lookup should be moved to Facet object?
		public function getAllContentItemsForFacetValue(f : FacetValue) : Array {
			if(allContentItemsForFacetValue[f] == undefined) {
				allContentItemsForFacetValue[f] = [];
			}
			return allContentItemsForFacetValue[f];
		}

		public function getNumContentItemsForFacetValue(f : FacetValue) : int {
			return getAllContentItemsForFacetValue(f).length;
		}

		// adds a content items
		private function addContentItem(c : ContentItem) : ContentItem {
			if(!contentItemsById[c.id]) {
				allContentItems.push(c);
				contentItemsById[c.id] = c;
				facetValuesForContentItem[c] = new Array();
				return c;	
			} else {
				// TODO: adopt new values?
				return contentItemsById[c.id]; 
			}
		};

		// short cut function with a lengthy name
		// will create facet value if necessary!
		public function assignFacetValueToContentItemByName(contentItemOrId : *, facetName : String, facetValueName : String) : void {
			var contentItem : ContentItem = (contentItemOrId as ContentItem) || getContentItemById(contentItemOrId);
			var facet : Facet = facet(facetName);
			var facetValue : FacetValue = facet.facetValue(facetValueName);
			if(facetValueName == null) {
				throw new Error("facetValueName cannot be null");
			}
			if(facetValue == null) {
				facetValue = facet.createFacetValue(facetValueName);
			}
			assignFacetValueToContentItem(facetValue, contentItem);
		}		

		// REVISIT: lookup should be moved to Facet object
		public function assignFacetValueToContentItem(f : FacetValue, c : ContentItem) : void {
			if(f == null || c == null) {
				throw new Error("*** NULL VALUE: assignFacetValueToContentItem " + f + " " + c);
			}
						
			if(allContentItemsForFacetValue[f] == undefined) {
				allContentItemsForFacetValue[f] = [];
			}
			
			allContentItemsForFacetValue[f].push(c);
			facetValuesForContentItem[c].push(f);
			c.facetValues[f] = true;
			/*
			// check if facetValue is hierarchical and has a parent
			var ff : HierarchicalFacetValue = f as HierarchicalFacetValue;
			if(ff != null && ff.hasParent()) {
				assignFacetValueToContentItem(ff.parentFacetValue, c);
			}
			 * 
			 */
		};	

		//---------------------------------------
		// FILTERS
		//---------------------------------------
		public function resetFilters() : void {
			for each(var facet:Facet in facets) {
				for each(var facetValue:FacetValue in facet.facetValues) {
					facetValue.selected = false;
				}
			}
			applyFilters();
		};

		// gets selected filters from facets, stores them in activeFilters dict
		public function updateActiveFilters() : void {
			activeFilters = new Dictionary();
			for each(var facet:Facet in facets) {
				facet.updateContentItemFilter();
				if(facet.filter.active) activeFilters[facet] = facet.filter;
			}
		};

		// updates ContentItem states, filteredContentItems based on filters
		public function applyFilters() : void {
			trace("Model.applyFilters");
			
			updateActiveFilters();
			var c : ContentItem;
			
			filteredContentItems = [];				
				
			for each(c in allContentItems) {
				if(contentItemMatchesFilters(c, activeFilters)) {
					c.filteredOut = false;
					filteredContentItems.push(c);
				} else {
					c.filteredOut = true;
				}
			}
			
			Logger.info("Model. onFilteredContentItemsChanged: " + filteredContentItems.length + " results");
		};

		// tests if a contentitem matches all filters in passed filters dictionary 
		protected function contentItemMatchesFilters(c : ContentItem, filters : Dictionary) : Boolean {
			for each(var f:Filter in filters) {
				if(!f.match(c)) return false;				
			}	
			// all good
			return true;
		}

		public function getTotalNumContentItemsForFacetValue(f : FacetValue) : int {
			return getAllContentItemsForFacetValue(f).length;
		}

		public function getFilteredNumContentItemsForFacetValue(f : FacetValue) : int {
			// get all ContentItems
			var contentItems : Array = getAllContentItemsForFacetValue(f);
			// count all which are not filtered out
			var count : int = 0;
			for each (var c:ContentItem in contentItems) {
				if(!c.filteredOut) {
					count++;
				}
			}
			return count;
		}
	}
}