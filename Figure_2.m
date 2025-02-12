%Asset value
%
%Created Aug 14 2024
%by Robert Fofrich Navarro
%
%Calculates corporate asset value and assigns values to power plant parent company
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
FUEL = 1;% sets fuel %1 COAL,2 GAS, 3 OIL, 4 Combined
clearvars -except ii; close all

TJ_to_BTu = 1/(9.478*1e8);
Kg_CO2_to_t_C02 = 1/1000;
BTu_perKWh_to_BTu_perMWh = 1000;

max_marker_size = 3000;
min_marker_size = 200; 


PowerPlantFuel = ["Coal", "Gas", "Oil"];
saveyear = 0;%saves decommission year; any other number loads decommission year
saveresults = 1;
randomsave = 1;%set to 1 to save MC randomization; zero value  loads MC randomization - section 11 only


if FUEL <4
CombineFuelTypeResults = 0;
elseif FUEL >3
CombineFuelTypeResults = 1;
end

current_year = 2024;
cutoffyear = 2035;%follows the index for carbontaxyear vector
CarbonPrice = 2000;%$/tCO2
CarbonTaxYear = current_year:2100;%sets the year for which the carbon tax is at its maximum

[ Dateindx] = find(CarbonTaxYear == cutoffyear);

StartYear = 1900;
EndYear = current_year;
Year = StartYear:EndYear;

RetailtoWholesaleConversionFactor = 1;%assumption

%Median PowerPlant Costs and Life from IPCC AR5 WGIII
%(https://www.ipcc.ch/site/assets/uploads/2018/02/ipcc_wg3_ar5_annex-iii.pdf)
%Power plant life

interest_rate_construction = .05; % interest rate over the construction loan (set as 5%)
DiscountRate = .1; %rate used by IEA 2020 report, 7% is in a highly regulated market, and 10% is in an environment with high risks

mean_Life_coal = 40;
Variable_OM_coal = 3.4;% $/MWh
Fixed_OM_coal = 23*1000;% $/MW
Construction_period_coal = 6; 
Capital_costs_coal = 2200*1000;% $/MW
Fuel_costs_coal = 4.1/3.6; % $/MWh
alpha_coal = DiscountRate/(1-(1+DiscountRate).^-mean_Life_coal);% percent
eta_coal = .39;% percent
Investment_costs_coal = (Capital_costs_coal/mean_Life_coal)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_coal)));

mean_Life_gas = 30;
Variable_OM_gas = 3.2;% $/MWh
Fixed_OM_gas = 7*1000;% $/MW
Construction_period_gas = 4; 
Capital_costs_gas = 1100*1000;% $/MW
Fuel_costs_gas = 8.9*3.6; % $/MWh
alpha_gas = DiscountRate/(1-(1+DiscountRate).^-mean_Life_gas);% percent
eta_gas = .55;% percent
Investment_costs_gas = (Capital_costs_gas/mean_Life_gas)*sum((1+interest_rate_construction)*(1+(0/(1+DiscountRate).^mean_Life_gas)));

%Power plant ranges
LifeTimeRange = 20:5:60; 
CapacityFactorRange = .25:.05:.75;
AnnualHours = 8760;

%plus/minus age
Age_span = 20;% Power plant age range

%plus/minus CF
CF_span = .25;% Power plant capacity factor range
if FUEL == 1
years = 2021:(current_year + mean_Life_coal);
elseif FUEL == 2
years = 2021:(current_year + mean_Life_gas);
end

load(['../Data/Results/DecommissionYear' PowerPlantFuel{FUEL} ''])
if FUEL == 1
    load '../Data/Results/PowerPlantFinances_byCompany_Coal'
    load '../Data/Results/PowerPlantFinances_byCountry_Coal'
    load '../Data/Results/CoalAnnualEmissions.mat'
    load ../Data/Results/CoalCompanyCapacity.mat
    load ../Data/Results/CoalRevenue.mat 
    load ../Data/Results/CoalStrandedAssets.mat
    load '../Data/Results/colorschemecategoryCoal2'

    RegionList = {'United States','Latin America','China','Europe',...
        'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};
    
    RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
    Coal_company_country_strings = strings(length(CoalAnnualEmissions_Company),1);
    Company_RGB_colors = zeros(length(CoalAnnualEmissions_Company),3);

    for i = 1:length(CoalAnnualEmissions_Company)
        for j = 1:length(RegionList)
            if colorschemecategory(i) == j
                Coal_company_country_strings(i) = RegionList(j);
                Company_RGB_colors(i,:) = RGB_colors(j,:);
            end
        end
    end

    mean_Life = mean_Life_coal;


    Unknown_companies = {'other', 'others', 'other states','other unknownmixed entity types'};
    Unknown_companies_index = find(ismember(PowerPlantString_ByCompany, Unknown_companies));
    Unknown_companies_emissions = CoalAnnualEmissions_Company(Unknown_companies_index);
    Unknown_companies_capacity = TotalPowerPlantCapacitybyCompany(Unknown_companies_index,:);
    Unknown_companies_stranded_assets = StrandedAssetValuebyCompany(Unknown_companies_index,:);

    StrandedAssetValuebyCompany(Unknown_companies_index,:) = 0;%removes unknown companies after extracting them above
    TotalPowerPlantCapacitybyCompany(Unknown_companies_index,:) = 0;
    CoalAnnualEmissions_Company(Unknown_companies_index) = 0;

    ProfitsByCompany_CarbonTax = squeeze(sum(PowerPlantFinances_byCompany(:,1:40,2),2));%company,year,variable
    StrandedAssetsbyCompany = StrandedAssetValuebyCompany(:,2);
    EmissionsbyCompany = squeeze(CoalAnnualEmissions_Company(:,1));
    AnnualCapacityByCompany = squeeze(TotalPowerPlantCapacitybyCompany(:,1));
    NumberofPlantsperCompanyperYear = squeeze(NumberofPlantsperCompanyperYear(:,1));
    Lifeleft = mean_Life - PowerPlantLife_byCompany(:,1);

    AnnualEmissionsByCompany_Coal_strings(EmissionsbyCompany==0)=[];
    CommittedEmissions(EmissionsbyCompany==0)=[];
    StrandedAssetsbyCompany(EmissionsbyCompany == 0)=[];
    ProfitsByCompany_CarbonTax(EmissionsbyCompany ==0)=[];
    RevenuebyCompany(EmissionsbyCompany == 0)= [];
    colorschemecategory(EmissionsbyCompany==0)=[];
    AnnualCapacityByCompany(EmissionsbyCompany==0)=[];
    NumberofPlantsperCompanyperYear(EmissionsbyCompany==0)=[];
    Coal_company_country_strings(EmissionsbyCompany==0)=[];
    Company_RGB_colors(EmissionsbyCompany==0,:)=[];
    Lifeleft(EmissionsbyCompany==0)=[];
    EmissionsbyCompany(EmissionsbyCompany ==0)=[];

    CommittedEmissions(ProfitsByCompany_CarbonTax==0)=[];
    AnnualEmissionsByCompany_Coal_strings(ProfitsByCompany_CarbonTax==0)=[];
    StrandedAssetsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
    RevenuebyCompany(ProfitsByCompany_CarbonTax == 0) = [];
    EmissionsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
    colorschemecategory(ProfitsByCompany_CarbonTax==0)=[];
    Coal_company_country_strings(ProfitsByCompany_CarbonTax==0)=[];
    AnnualCapacityByCompany(ProfitsByCompany_CarbonTax==0)=[];
    NumberofPlantsperCompanyperYear(ProfitsByCompany_CarbonTax==0)=[];
    Company_RGB_colors(ProfitsByCompany_CarbonTax==0,:)=[];
    Lifeleft(ProfitsByCompany_CarbonTax==0)=[];
    ProfitsByCompany_CarbonTax(ProfitsByCompany_CarbonTax==0)=[];


    [StrandedAssetsbyCompany,Indx] = maxk(StrandedAssetsbyCompany,100);
    AnnualEmissionsByCompany_Coal_strings = AnnualEmissionsByCompany_Coal_strings(Indx);
    RevenuebyCompany = RevenuebyCompany(Indx);
    ProfitsByCompany_CarbonTax = ProfitsByCompany_CarbonTax(Indx);
    colorschemecategory = colorschemecategory(Indx);
    AnnualCapacityByCompany = AnnualCapacityByCompany(Indx);
    NumberofPlantsperCompanyperYear = NumberofPlantsperCompanyperYear(Indx);
    EmissionsbyCompany = EmissionsbyCompany(Indx);
    CommittedEmissions = CommittedEmissions(Indx);
    Coal_company_country_strings = Coal_company_country_strings(Indx);
    Company_RGB_colors = Company_RGB_colors(Indx,:);
    Lifeleft = Lifeleft(Indx,:);

    EmissionsbyCompany = EmissionsbyCompany/(1e6); %converts to Mt CO2
    StrandedAssetsbyCompany = StrandedAssetsbyCompany/(1e9); %converts to billions of $
    RevenuebyCompany = RevenuebyCompany/(1e9); %converts to billions of $
    save('revenuebycompany_coal.mat','RevenuebyCompany')

    stranded_marker_size = (StrandedAssetsbyCompany-min(StrandedAssetsbyCompany))/(max(StrandedAssetsbyCompany)-min(StrandedAssetsbyCompany));%normalized data between 0 and 1 for plotting
    stranded_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * stranded_marker_size;

    Emission_marker_sizes = (EmissionsbyCompany-min(EmissionsbyCompany))/(max(EmissionsbyCompany)-min(EmissionsbyCompany));%normalized data between 0 and 1 for plotting
    Emission_scaled_sizes = min_marker_size + (max_marker_size - min_marker_size) * Emission_marker_sizes;

    Standardized_marker_size = (StrandedAssetsbyCompany./RevenuebyCompany)*100;
    Standardized_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * Standardized_marker_size;

    profits_marker_size = (ProfitsByCompany_CarbonTax-min(ProfitsByCompany_CarbonTax))/(max(ProfitsByCompany_CarbonTax)-min(ProfitsByCompany_CarbonTax));%normalized data between 0 and 1 for plotting
    Profits_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * profits_marker_size;

    AnnualCapacityByCompany = AnnualCapacityByCompany/1000;
    capacity_marker_size = (AnnualCapacityByCompany-min(AnnualCapacityByCompany))/(max(AnnualCapacityByCompany)-min(AnnualCapacityByCompany));%normalized data between 0 and 1 for plotting
    capacity_scaled_sizes = min_marker_size + (max_marker_size - min_marker_size) * capacity_marker_size;


    figure()
    scatter(EmissionsbyCompany,StrandedAssetsbyCompany,capacity_scaled_sizes,Company_RGB_colors,'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    xlabel('Emissions')
    ylabel('Stranded assets')
    title('Size by revenue')
    % xlim([min(EmissionsbyCompany)-1000,max(EmissionsbyCompany)+1000])
    % ylim([1e10,1.3e12])
    

    figure()
    scatter(RevenuebyCompany,StrandedAssetsbyCompany,Emission_scaled_sizes,Company_RGB_colors,'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    xlabel('Revenue')
    ylabel('Stranded assets')
    title('Size by emissions')
    % ylim([1e10,1.3e12])
    

    figure()
    scatter(EmissionsbyCompany,StrandedAssetsbyCompany,capacity_scaled_sizes,Company_RGB_colors,'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('CO2 emissions')
    ylabel('Stranded assets')
    % xlim([1e6,1.5e9])
    % ylim([1e10,1.3e12])
%         legend(RegionList)
    ax = gca;
    exportgraphics(ax,['../Plots/coal scatter emissions.eps'],'ContentType','vector');
    % save('../Data/Results/CoalEmissionsbyCompany.mat','Profits_size','EmissionsbyCompany','StrandedAssetsbyCompany')

    Capacity_sizes=AnnualCapacityByCompany*500/(max(AnnualCapacityByCompany)/2);

    figure()
    scatter(AnnualCapacityByCompany,StrandedAssetsbyCompany,Profits_scaled_size,Company_RGB_colors,'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('Installed capacity')
    ylabel('Stranded assets')
    % xlim([min(AnnualCapacityByCompany), 1500000])
    % ylim([1e10,1.3e12])
    ax = gca;
    exportgraphics(ax,['../Plots/coal scatter installed capacity.eps'],'ContentType','vector');
    % save('../Data/Results/CoalAnnualCapacityByCompany.mat','Profits_size','AnnualCapacityByCompany','StrandedAssetsbyCompany')

    Plant_sizes=NumberofPlantsperCompanyperYear*5000/(max(NumberofPlantsperCompanyperYear)/2);

    figure()
    scatter(NumberofPlantsperCompanyperYear,StrandedAssetsbyCompany,Profits_scaled_size,Company_RGB_colors,'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('Number of plants')
    ylabel('Stranded assets')
    % xlim([min(NumberofPlantsperCompanyperYear),max(NumberofPlantsperCompanyperYear)+3000])
    % ylim([1e10,1.3e12])
    ax = gca;
    exportgraphics(ax,['../Plots/coal scatter number of plants.eps'],'ContentType','vector');
    % save('../Data/Results/CoalNumberofPlantsperCompanyperYear.mat','Profits_size','NumberofPlantsperCompanyperYear','StrandedAssetsbyCompany')

    Lifeleft(Lifeleft<=0)=randi(5);
    Lifeleft_size =Lifeleft*500/40;

    figure()
    scatter(Lifeleft,StrandedAssetsbyCompany,capacity_scaled_sizes,Company_RGB_colors,'filled')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('Years to retirement')
    ylabel('Stranded assets')
    % ylim([1e10,1.3e12])
    ax = gca;
    exportgraphics(ax,['../Plots/coal scatter years to retirement.eps'],'ContentType','vector');
    % save('../Data/Results/CoalLifeleft.mat','Profits_size','Lifeleft','StrandedAssetsbyCompany')

    LegendColor = 1:1:9;

    figure()
    scatter(LegendColor',LegendColor',LegendColor*100,RGB_colors,'filled')
    text(LegendColor,LegendColor,RegionList)
    legend(RegionList{:})

    figure()
    scatter(Lifeleft,StrandedAssetsbyCompany,AnnualCapacityByCompany*25,Company_RGB_colors,'filled')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('Years to retirement')
    ylabel('Stranded assets')
    % ylim([1e10,1e12])
    xlim([0, 40])
    ax = gca;
    exportgraphics(ax,'../Plots/coal scatter stranded assets remaining life standardized size.eps','ContentType','vector');

    figure()
    scatter(EmissionsbyCompany,StrandedAssetsbyCompany,AnnualCapacityByCompany*25,Company_RGB_colors,'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('CO2 emissions')
    ylabel('Stranded assets')
    % xlim([1e7,1e8])
    % ylim([1e1,1e3])
%         legend(RegionList)
    ax = gca;
    exportgraphics(ax,'../Plots/coal scatter stranded assets EmissionsbyCompany standardized size.eps','ContentType','vector');

    EmissionsbyCompany = EmissionsbyCompany*1e6;
    EmissionsPerStrandedAssets = ((CommittedEmissions)./(StrandedAssetsbyCompany*1e9)); %converts stranded assets back to $ instead of billions of dollar
    save('../Data/Results/EmissionsPerStrandedAssets_coal.mat','EmissionsPerStrandedAssets','EmissionsbyCompany','CommittedEmissions','StrandedAssetsbyCompany','Company_RGB_colors','AnnualEmissionsByCompany_Coal_strings')


    figure()
    scatter((EmissionsbyCompany),EmissionsPerStrandedAssets,100,Company_RGB_colors)
    set(gca,'xscale','log')
    xlabel('Annual emissions (t CO2)')
    ylabel('Annual emissions per dollar (tons CO2 per $)')
    % xlim([1.5e6,1e9])
    % ylim([0,60])
    ax = gca;
    exportgraphics(ax,'../Plots/Emissions per stranded assets coal.eps','ContentType','vector');

    
elseif FUEL == 2


    if FUEL == 1
        mean_Life = mean_Life_coal;
    elseif FUEL == 2
        mean_Life = mean_Life_gas;
    end

    load '../Data/Results/PowerPlantFinances_byCompany_Gas'
    load '../Data/Results/PowerPlantFinances_byCountry_Gas'
    load '../Data/Results/GasAnnualEmissions.mat'
    load ../Data/Results/GasCompanyCapacity.mat
    load ../Data/Results/GasStrandedAssets.mat
    load ../Data/Results/GasRevenue.mat
    load '../Data/Results/colorschemecategoryGas2'

    RegionList = {'United States','Latin America','China','Europe',...
        'Middle East and Africa','Asia','Former Soviet','Australia, Canada, New Zealand','India'};
    
    RGB_colors = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 0 0.4470 0.7410; 0.8500 0.3250 0.0980];
    Gas_company_country_strings = strings(length(GasAnnualEmissions_Company),1);
    Company_RGB_colors = zeros(length(GasAnnualEmissions_Company),3);

    for i = 1:length(GasAnnualEmissions_Company)
        for j = 1:length(RegionList)
            if colorschemecategory(i) == j
                Gas_company_country_strings(i) = RegionList(j);
                Company_RGB_colors(i,:) = RGB_colors(j,:);
            end
        end
    end


    Unknown_companies = {'other', 'others', 'other states','other unknownmixed entity types'};
    Unknown_companies_index = find(ismember(PowerPlantString_ByCompany, Unknown_companies));
    Unknown_companies_emissions = GasAnnualEmissions_Company(Unknown_companies_index);
    Unknown_companies_capacity = TotalPowerPlantCapacitybyCompany(Unknown_companies_index,:);
    Unknown_companies_stranded_assets = StrandedAssetValuebyCompany(Unknown_companies_index,:);

    StrandedAssetValuebyCompany(Unknown_companies_index,:) = 0;%removes unknown companies after extracting them above
    TotalPowerPlantCapacitybyCompany(Unknown_companies_index,:) = 0;
    GasAnnualEmissions_Company(Unknown_companies_index) = 0;



    ProfitsByCompany_CarbonTax = squeeze(sum(PowerPlantFinances_byCompany(:,1:30,2),2));%company,year,variable
    StrandedAssetsbyCompany = StrandedAssetValuebyCompany(:,2);
    EmissionsbyCompany = squeeze(GasAnnualEmissions_Company(:,1));
    AnnualCapacityByCompany = squeeze(TotalPowerPlantCapacitybyCompany(:,1));
    NumberofPlantsperCompanyperYear = squeeze(NumberofPlantsperCompanyperYear(:,1));
    Lifeleft = mean_Life - PowerPlantLife_byCompany(:,1);

    CommittedEmissions(EmissionsbyCompany==0)=[];
    AnnualEmissionsByCompany_Gas_strings(EmissionsbyCompany==0)=[];
    StrandedAssetsbyCompany(EmissionsbyCompany == 0)=[];
    ProfitsByCompany_CarbonTax(EmissionsbyCompany ==0)=[];
    RevenuebyCompany(EmissionsbyCompany == 0)= [];
    colorschemecategory(EmissionsbyCompany==0)=[];
    AnnualCapacityByCompany(EmissionsbyCompany==0)=[];
    NumberofPlantsperCompanyperYear(EmissionsbyCompany==0)=[];
    Gas_company_country_strings(EmissionsbyCompany==0)=[];
    Company_RGB_colors(EmissionsbyCompany==0,:)=[];
    Lifeleft(EmissionsbyCompany==0)=[];
    EmissionsbyCompany(EmissionsbyCompany ==0)=[];

    CommittedEmissions(ProfitsByCompany_CarbonTax==0)=[];
    AnnualEmissionsByCompany_Gas_strings(ProfitsByCompany_CarbonTax==0)=[];
    StrandedAssetsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
    RevenuebyCompany(ProfitsByCompany_CarbonTax == 0) = [];
    EmissionsbyCompany(ProfitsByCompany_CarbonTax==0)=[];
    colorschemecategory(ProfitsByCompany_CarbonTax==0)=[];
    Gas_company_country_strings(ProfitsByCompany_CarbonTax==0)=[];
    AnnualCapacityByCompany(ProfitsByCompany_CarbonTax==0)=[];
    NumberofPlantsperCompanyperYear(ProfitsByCompany_CarbonTax==0)=[];
    Company_RGB_colors(ProfitsByCompany_CarbonTax==0,:)=[];
    Lifeleft(ProfitsByCompany_CarbonTax==0)=[];
    ProfitsByCompany_CarbonTax(ProfitsByCompany_CarbonTax==0)=[];


    [StrandedAssetsbyCompany,Indx] = maxk(StrandedAssetsbyCompany,100);
    CommittedEmissions = CommittedEmissions(Indx);
    AnnualEmissionsByCompany_Gas_strings = AnnualEmissionsByCompany_Gas_strings(Indx);
    RevenuebyCompany = RevenuebyCompany(Indx);
    ProfitsByCompany_CarbonTax = ProfitsByCompany_CarbonTax(Indx);
    colorschemecategory = colorschemecategory(Indx);
    AnnualCapacityByCompany = AnnualCapacityByCompany(Indx);
    NumberofPlantsperCompanyperYear = NumberofPlantsperCompanyperYear(Indx);
    EmissionsbyCompany = EmissionsbyCompany(Indx);
    Gas_company_country_strings =Gas_company_country_strings(Indx);
    Company_RGB_colors = Company_RGB_colors(Indx,:);
    Lifeleft = Lifeleft(Indx,:);

    EmissionsbyCompany = EmissionsbyCompany/(1e6); %converts to Mt CO2
    StrandedAssetsbyCompany = StrandedAssetsbyCompany/(1e9); %converts to billions of $
    RevenuebyCompany = RevenuebyCompany/(1e9); %converts to billions of $

    stranded_marker_size = (StrandedAssetsbyCompany-min(StrandedAssetsbyCompany))/(max(StrandedAssetsbyCompany)-min(StrandedAssetsbyCompany));%normalized data between 0 and 1 for plotting
    stranded_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * stranded_marker_size;

    Emission_marker_sizes = (EmissionsbyCompany-min(EmissionsbyCompany))/(max(EmissionsbyCompany)-min(EmissionsbyCompany));%normalized data between 0 and 1 for plotting
    Emission_scaled_sizes = min_marker_size + (max_marker_size - min_marker_size) * Emission_marker_sizes;

    Standardized_marker_size = (StrandedAssetsbyCompany./RevenuebyCompany)*100;
    Standardized_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * Standardized_marker_size;

    profits_marker_size = (ProfitsByCompany_CarbonTax-min(ProfitsByCompany_CarbonTax))/(max(ProfitsByCompany_CarbonTax)-min(ProfitsByCompany_CarbonTax));%normalized data between 0 and 1 for plotting
    Profits_scaled_size = min_marker_size + (max_marker_size - min_marker_size) * profits_marker_size;

    AnnualCapacityByCompany = AnnualCapacityByCompany/1e3;
    capacity_marker_size = (RevenuebyCompany-min(RevenuebyCompany))/(max(RevenuebyCompany)-min(RevenuebyCompany));%normalized data between 0 and 1 for plotting
    capacity_scaled_sizes = min_marker_size + (max_marker_size - min_marker_size) * capacity_marker_size;
    save('revenuebycompany_gas.mat','RevenuebyCompany')

    figure()
    scatter(EmissionsbyCompany/1e6,StrandedAssetsbyCompany,capacity_scaled_sizes,Company_RGB_colors,'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    xlabel('Emissions')
    ylabel('Stranded assets')
    title('Size by revenue')
    % xlim([min(EmissionsbyCompany)-1000,max(EmissionsbyCompany)+1000])
    ylim([min(StrandedAssetsbyCompany),60])

    figure()
    scatter(RevenuebyCompany,StrandedAssetsbyCompany,Emission_scaled_sizes,Company_RGB_colors,'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    xlabel('Revenue')
    ylabel('Stranded assets')
    title('Size by emissions')
    % ylim([min(StrandedAssetsbyCompany),1.75e11])

    figure()
    scatter(EmissionsbyCompany,StrandedAssetsbyCompany,capacity_scaled_sizes,[Company_RGB_colors],'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('CO2 emissions')
    ylabel('Stranded assets')
    % xlim([1e6,1.75e8])
    % ylim([min(StrandedAssetsbyCompany),1.75e11])
%         legend(RegionList)
    ax = gca;
    % exportgraphics(ax,['../Plots/Gas scatter emissions.eps'],'ContentType','vector');

    Capacity_sizes=AnnualCapacityByCompany*500/(max(AnnualCapacityByCompany)/2);

    figure()
    scatter(AnnualCapacityByCompany,StrandedAssetsbyCompany,Profits_scaled_size,[Company_RGB_colors],'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('Installed capacity')
    ylabel('Stranded assets')
    % xlim([min(AnnualCapacityByCompany), 1e5])
    ylim([0,60])
    ax = gca;
    % exportgraphics(ax,['../Plots/Gas scatter installed capacity.eps'],'ContentType','vector');

    Plant_sizes=NumberofPlantsperCompanyperYear*5000/(max(NumberofPlantsperCompanyperYear)/2);

    figure()
    scatter(NumberofPlantsperCompanyperYear,StrandedAssetsbyCompany,Profits_scaled_size,[Company_RGB_colors],'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('Number of plants')
    ylabel('Stranded assets')
    % xlim([min(NumberofPlantsperCompanyperYear),1e3])
    % ylim([min(StrandedAssetsbyCompany),1.75e11])
    ax = gca;
    % exportgraphics(ax,['../Plots/Gas scatter number of plants.eps'],'ContentType','vector');

    Lifeleft(Lifeleft<=0)=1;
    Lifeleft_size =Lifeleft*500/40;

    figure()
    scatter(Lifeleft,StrandedAssetsbyCompany,capacity_scaled_sizes,[Company_RGB_colors],'filled')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('Years to retirement')
    ylabel('Stranded assets')
    % ylim([min(StrandedAssetsbyCompany),1.75e11])
    ax = gca;
    % exportgraphics(ax,['../Plots/Gas scatter years to retirement.eps'],'ContentType','vector');

    LegendColor = 1:1:9;

    figure()
    scatter(LegendColor',LegendColor',LegendColor*100,RGB_colors,'filled')
    text(LegendColor,LegendColor,RegionList)
    legend(RegionList{:})


    figure()
    scatter(Lifeleft,StrandedAssetsbyCompany,AnnualCapacityByCompany*25,Company_RGB_colors,'filled')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('Years to retirement')
    ylabel('Stranded assets')
    % ylim([min(StrandedAssetsbyCompany),1.2e11])
    xlim([0, 30])
    ylim([0, 200])
    ax = gca;
    exportgraphics(ax,'../Plots/gas scatter stranded assets remaining life standardized size.eps','ContentType','vector');

    figure()
    scatter(EmissionsbyCompany,StrandedAssetsbyCompany,AnnualCapacityByCompany*25,Company_RGB_colors,'filled')
    set(gca,'xscale','log')
    set(gca,'yscale','log')
    set(gca,'zscale','log')
    xlabel('CO2 emissions')
    ylabel('Stranded assets')
    % xlim([(min(EmissionsbyCompany)-10000000),max(EmissionsbyCompany)+2000])
    ylim([0, 200])
%         legend(RegionList)
    ax = gca;
    exportgraphics(ax,'../Plots/gas scatter stranded assets EmissionsbyCompany standardized size.eps','ContentType','vector');


    EmissionsbyCompany = EmissionsbyCompany*1e6;
    EmissionsPerStrandedAssets = ((CommittedEmissions)./(StrandedAssetsbyCompany*1e9)); %converts stranded assets back to $ instead of billions of dollar
    save('../Data/Results/EmissionsPerStrandedAssets_gas.mat','EmissionsPerStrandedAssets','EmissionsbyCompany','CommittedEmissions','StrandedAssetsbyCompany','Company_RGB_colors','AnnualEmissionsByCompany_Gas_strings')


    figure()
    scatter((EmissionsbyCompany*1e6),EmissionsPerStrandedAssets,100,Company_RGB_colors)
    set(gca,'xscale','log')
    xlabel('Annual emissions (t CO2)')
    ylabel('Annual emissions per dollar (t CO2 per $)')
    % xlim([1.5e6,1e9])
    ylim([0, 200])
    ax = gca;
    exportgraphics(ax,'../Plots/Emissions per stranded assets gas.eps','ContentType','vector');

end
